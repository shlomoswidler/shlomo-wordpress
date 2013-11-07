include_recipe "apache2"
if node['wordpress']['db']['host'] == "localhost"
  include_recipe "mysql::server" 
else
  include_recipe "mysql::client"
end

pkg = value_for_platform(
  %w(centos redhat scientific fedora amazon) => {
    "default" => "php53-mysql"
  },
  "default" => "php5-mysql"
)

package pkg do
  action :install
end

include_recipe "apache2::mod_php5"

if node[:wordpress].has_key?('fqdn')
  server_fqdn = node[:wordpress][:fqdn]
elsif node.has_key?("ec2")
  server_fqdn = node['ec2']['public_hostname']
elsif node.has_key?("opsworks")
  server_fqdn = node[:opsworks][:instance][:public_dns_name]
else
  server_fqdn = node['fqdn']
end

node.set_unless['wordpress']['db']['password'] = ::SecurePassword.secure_password
node.set_unless['wordpress']['keys']['auth'] = ::SecurePassword.secure_password
node.set_unless['wordpress']['keys']['secure_auth'] = ::SecurePassword.secure_password
node.set_unless['wordpress']['keys']['logged_in'] = ::SecurePassword.secure_password
node.set_unless['wordpress']['keys']['nonce'] = ::SecurePassword.secure_password


if node['wordpress']['version'] == 'latest'
  # WordPress.org does not provide a sha256 checksum, so we'll use the sha1 they do provide
  require 'digest/sha1'
  require 'open-uri'
  local_file = "#{Chef::Config[:file_cache_path]}/wordpress-latest.tar.gz"
  latest_sha1 = open('http://wordpress.org/latest.tar.gz.sha1') {|f| f.read }
  unless File.exists?(local_file) && ( Digest::SHA1.hexdigest(File.read(local_file)) == latest_sha1 )
    remote_file "#{Chef::Config[:file_cache_path]}/wordpress-latest.tar.gz" do
      source "http://wordpress.org/latest.tar.gz"
      mode "0644"
    end
  end
else
  remote_file "#{Chef::Config[:file_cache_path]}/wordpress-#{node['wordpress']['version']}.tar.gz" do
    source "#{node['wordpress']['repourl']}/wordpress-#{node['wordpress']['version']}.tar.gz"
    mode "0644"
  end
end

directory node['wordpress']['dir'] do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
end

execute "untar-wordpress" do
  cwd node['wordpress']['dir']
  command "tar --strip-components 1 -xzf #{Chef::Config[:file_cache_path]}/wordpress-#{node['wordpress']['version']}.tar.gz"
  creates "#{node['wordpress']['dir']}/wp-settings.php"
end

execute "mysql-install-wp-privileges" do
  command "/usr/bin/mysql -h #{node['wordpress']['db']['host']} -u #{node['mysql']['server_root_user']} -p\"#{node['mysql']['server_root_password']}\" mysql < #{node['mysql']['conf_dir']}/wp-grants.sql"
  action :nothing
end

template "#{node['mysql']['conf_dir']}/wp-grants.sql" do
  source "grants.sql.erb"
  cookbook 'wordpress'
  owner "root"
  group "root"
  mode "0600"
  variables(
    :user     => node['wordpress']['db']['user'],
    :password => node['wordpress']['db']['password'],
    :database => node['wordpress']['db']['database']
  )
  notifies :run, "execute[mysql-install-wp-privileges]", :immediately
end

execute "create #{node['wordpress']['db']['database']} database" do
  command "/usr/bin/mysql -h #{node['wordpress']['db']['host']} -u #{node['mysql']['server_root_user']} -p\"#{node['mysql']['server_root_password']}\" -e \"create database if not exists #{node['wordpress']['db']['database']}\""
  notifies :create, "ruby_block[save node data]", :immediately unless Chef::Config[:solo]
end

# save node data after writing the MYSQL root password, so that a failed chef-client run that gets this far doesn't cause an unknown password to get applied to the box without being saved in the node data.
unless Chef::Config[:solo]
  ruby_block "save node data" do
    block do
      node.save
    end
    action :create
  end
end

log "wordpress_install_message" do
  action :nothing
  message "Navigate to 'http://#{server_fqdn}/wp-admin/install.php' to complete wordpress installation"
end

template "#{node['wordpress']['dir']}/wp-config.php" do
  source "wp-config.php.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
    :database        => node['wordpress']['db']['database'],
    :user            => node['wordpress']['db']['user'],
    :password        => node['wordpress']['db']['password'],
    :host            => node['wordpress']['db']['host'],
    :auth_key        => node['wordpress']['keys']['auth'],
    :secure_auth_key => node['wordpress']['keys']['secure_auth'],
    :logged_in_key   => node['wordpress']['keys']['logged_in'],
    :nonce_key       => node['wordpress']['keys']['nonce'],
    :lang            => node['wordpress']['languages']['lang'],
    :wp_config_extras =>node['wordpress']['wp_config_extras']
  )
  notifies :write, "log[wordpress_install_message]"
end

unless node['wordpress']['table_prefix'].nil?
  execute "set table prefix" do
    command <<-EOH
      sed -i -e "s/table_prefix[[:space:]]*=.*$/table_prefix='#{node['wordpress']['table_prefix']}';/" #{node['wordpress']['dir']}/wp-config.php
    EOH
    not_if {
      shell = Mixlib::ShellOut.new("grep \"table_prefix[[:space:]]*=[[:space:]]*'#{node['wordpress']['table_prefix']}'\" #{node['wordpress']['dir']}/wp-config.php")
      shell.run_command
      shell.exitstatus && shell.stdout.length > 1
    }
    notifies :write, "log[wordpress_install_message]"
  end
end

include_recipe "apache2::mod_rewrite"
include_recipe "apache2::mod_ssl"

apache_site "000-default" do
  enable false
end

cookbook_file "#{node[:apache][:dir]}/sites-available/wordpress.conf.inc" do
  source "wordpress.conf.inc"
  user 'root'
  group 'root'
  mode 00644
end

template "#{node[:apache][:dir]}/sites-available/wordpress.conf.rewrite.inc" do
  source "wordpress.conf.rewrite.inc.erb"
  user 'root'
  group 'root'
  mode 00644
  variables( { :server_name => server_fqdn } )
end

web_app "wordpress" do
  template "wordpress.conf.erb"
  docroot node['wordpress']['dir']
  server_name server_fqdn
  server_aliases node['wordpress']['server_aliases']
  admin_ips node['wordpress']['admin_ips']
end

if node[:wordpress][:web_root_overlay_bundle] && node[:wordpress][:web_root_overlay_bundle][:region] && \
  node[:wordpress][:web_root_overlay_bundle][:s3_url]
  
  include_recipe 'awscli'
  
  bundle_basename = File.basename(node[:wordpress][:web_root_overlay_bundle][:s3_url])
  
  ruby_block "download webroot overlay bundle" do
    block do
      InstanceMetadata.wait_for_instance_IAM_metadata_to_be_available
      shell = Mixlib::ShellOut.new("aws --region #{node[:wordpress][:web_root_overlay_bundle][:region]} s3 cp #{node[:wordpress][:web_root_overlay_bundle][:s3_url]} #{node[:wordpress][:dir]}")
      result= shell.run_command
      if result.exitstatus != 0
        raise "Failed to download webroot overlay bundle from #{node[:wordpress][:web_root_overlay_bundle][:s3_url]}\nSTDERR:\n"+shell.stderr+"\nSTDOUT:\n"+shell.stdout
      end
    end
    not_if { File.exists?("#{node[:wordpress][:dir]}/#{bundle_basename}") }
    notifies :run, "execute[open webroot overlay bundle]", :immediately
  end
  
  execute "open webroot overlay bundle" do
    cwd node[:wordpress][:dir]
    command "tar xvzf #{bundle_basename}"
    action :nothing
    notifies :run, "execute[fix wordpress dir owner and permissions]", :immediately
  end
  
  execute "fix wordpress dir owner and permissions" do
    user 'root'
    cwd node[:wordpress][:dir]
    command <<-EOH
      chown #{node[:apache][:user]}:#{node[:apache][:group]} .
      chown -R #{node[:apache][:user]}:#{node[:apache][:group]} *
      find . -type d -exec chmod 755 {} \;
      find . -type f -exec chmod 644 {} \;
    EOH
    action :nothing
    notifies :run, "execute[protect webroot bundle from being read]", :immediately
  end
  
  execute "protect webroot bundle from being read" do
    command "chmod 000 #{node[:wordpress][:dir]}/#{bundle_basename}"
    action :nothing
  end

end
