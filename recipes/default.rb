include_attribute "wordpress"
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

if node.has_key?("ec2")
  server_fqdn = node['ec2']['public_hostname']
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

apache_site "000-default" do
  enable false
end

web_app "wordpress" do
  template "wordpress.conf.erb"
  cookbook "wordpress"
  docroot node['wordpress']['dir']
  server_name server_fqdn
  server_aliases node['wordpress']['server_aliases']
end
