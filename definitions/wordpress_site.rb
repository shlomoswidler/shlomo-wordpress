define :wordpress_site, \
  :template => "wordpress.conf.erb", \
  :cookbook => nil,
  :db => nil, \
  :fqdn => nil, \
  :keys => nil, \
  :version => "latest", \
  :dir => "/var/www/wordpress", \
  :repourl => nil, \
  :server_aliases => nil, \
  :table_prefix => "wp_", \
  :languages => nil, \
  :wp_config_extras => nil, \
  :web_root_overlay_bundle => nil, \
  :admin_ips => nil \
do

  app_name = params[:name]

  include_recipe "apache2"
  if params[:db][:host] == "localhost"
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

  server_fqdn = params[:fqdn]
  if server_fqdn.nil?
    if node.has_key?("ec2")
      server_fqdn = node[:ec2][:public_hostname]
    elsif node.has_key?("opsworks")
      server_fqdn = node[:opsworks][:instance][:public_dns_name]
    else
      server_fqdn = node[:fqdn]
    end
  end

  params[:db][:password] = ::SecurePassword.secure_password if params[:db][:password].nil?
  params[:keys] = {} if params[:keys].nil?
  params[:keys][:auth] = ::SecurePassword.secure_password if params[:keys][:auth].nil?
  params[:keys][:secure_auth] = ::SecurePassword.secure_password if params[:keys][:secure_auth].nil?
  params[:keys][:logged_in] = ::SecurePassword.secure_password if params[:keys][:logged_in].nil?
  params[:keys][:nonce] = ::SecurePassword.secure_password if params[:keys][:nonce].nil?
  
  if params[:version] == 'latest'
    # WordPress.org does not provide a sha256 checksum, so we'll use the sha1 they do provide
    require 'digest/sha1'
    require 'open-uri'
    local_file = "#{Chef::Config[:file_cache_path]}/wordpress-latest.tar.gz"
    latest_sha1 = open('http://wordpress.org/latest.tar.gz.sha1') {|f| f.read }
    unless File.exists?(local_file) && ( Digest::SHA1.hexdigest(File.read(local_file)) == latest_sha1 )
      remote_file "Download latest wordpress for #{app_name}" do
        path "#{Chef::Config[:file_cache_path]}/wordpress-latest.tar.gz"
        source "http://wordpress.org/latest.tar.gz"
        mode "0644"
      end  
    end
  else
    remote_file "Download wordpress version #{params[:version]} for #{app_name}" do
      path "#{Chef::Config[:file_cache_path]}/wordpress-#{params[:version]}.tar.gz"
      source "#{params[:repourl]}/wordpress-#{params[:version]}.tar.gz"
      mode "0644"
    end
  end

  params[:docroot] = params[:dir]+"/webroot"
  directory params[:docroot] do
    owner "root"
    group "root"
    mode "0755"
    action :create
    recursive true
  end

  execute "untar-wordpress-in-#{params[:docroot]}" do
    cwd params[:docroot]
    command "tar --strip-components 1 -xzf #{Chef::Config[:file_cache_path]}/wordpress-#{params[:version]}.tar.gz"
    creates "#{params[:docroot]}/wp-settings.php"
  end

  execute "mysql-install-wp-privileges-#{params[:db][:database]}" do
    command "/usr/bin/mysql -h #{params[:db][:host]} -u #{node[:mysql][:server_root_user]} -p\"#{node[:mysql][:server_root_password]}\" mysql < #{node[:mysql][:conf_dir]}/wp-grants-#{params[:db][:database]}.sql"
    action :nothing
  end

  template "#{node[:mysql][:conf_dir]}/wp-grants-#{params[:db][:database]}.sql" do
    source "grants.sql.erb"
    owner "root"
    group "root"
    mode "0600"
    variables(
      :user     => params[:db][:user],
      :password => params[:db][:password],
      :database => params[:db][:database]
    )
    notifies :run, "execute[mysql-install-wp-privileges-#{params[:db][:database]}]", :immediately
  end

  execute "create #{params[:db][:database]} database" do
    command "/usr/bin/mysql -h #{params[:db][:host]} -u #{node[:mysql][:server_root_user]} -p\"#{node[:mysql][:server_root_password]}\" -e \"create database if not exists #{params[:db][:database]}\""
    notifies :create, "ruby_block[save node data]", :immediately unless Chef::Config[:solo]
  end

  # save node data after writing the MYSQL root password, so that a failed chef-client run that gets this far doesn't cause an unknown password to get applied to the box without being saved in the node data.
  unless Chef::Config[:solo]
    ruby_block "save node data for #{app_name}" do
      block do
        node.save
      end
      action :create
    end
  end

  log "wordpress_install_message-in-#{app_name}" do
    action :nothing
    message "Navigate to 'http://#{server_fqdn}/wp-admin/install.php' to complete #{app_name} wordpress installation"
  end

  template "#{params[:docroot]}/wp-config.php" do
    source "wp-config.php.erb"
    owner "root"
    group "root"
    mode "0644"
    variables(
      :database        => params[:db][:database],
      :user            => params[:db][:user],
      :password        => params[:db][:password],
      :host            => params[:db][:host],
      :auth_key        => params[:keys][:auth],
      :secure_auth_key => params[:keys][:secure_auth],
      :logged_in_key   => params[:keys][:logged_in],
      :nonce_key       => params[:keys][:nonce],
      :lang            => params[:languages][:lang],
      :table_prefix    => params[:table_prefix],
      :wp_config_extras =>params[:wp_config_extras]
    )
    notifies :write, "log[wordpress_install_message-in-#{app_name}]"
  end

  include_recipe "apache2::mod_rewrite"
  include_recipe "apache2::mod_ssl"

  apache_site "000-default" do
    enable false
  end

  cookbook_file "#{node[:apache][:dir]}/sites-available/#{app_name}.conf.inc" do
    source "wordpress.conf.inc"
    user 'root'
    group 'root'
    mode 00644
  end

  template "#{node[:apache][:dir]}/sites-available/#{app_name}.conf.rewrite.inc" do
    source "wordpress.conf.rewrite.inc.erb"
    user 'root'
    group 'root'
    mode 00644
    variables( { :server_name => server_fqdn } )
  end

  ## IDEALLY we would simply call the web_app definition here. But it doesn't work.
  ## Not sure why, but as a workaround, I'm monkey-including the body of the web_app definition
  ## directly into here.

  include_recipe 'apache2::default'
  include_recipe 'apache2::mod_rewrite'
  include_recipe 'apache2::mod_deflate'
  include_recipe 'apache2::mod_headers'

  params[:server_name] = server_fqdn
  template "#{node['apache']['dir']}/sites-available/#{app_name}.conf" do
    source   params[:template]
    owner    'root'
    group    node['apache']['root_group']
    mode     '0644'
    cookbook params[:cookbook] if params[:cookbook]
    variables params
    if ::File.exists?("#{node['apache']['dir']}/sites-enabled/#{app_name}.conf")
      notifies :reload, 'service[apache2]'
    end
  end

  apache_site "#{app_name}.conf" do
    enable true
  end
  
  ## End of monkey-inclusion of the web_app definition.
  
  if params[:web_root_overlay_bundle] && params[:web_root_overlay_bundle][:region] && \
    params[:web_root_overlay_bundle][:s3_url]
  
    include_recipe 'awscli'
  
    bundle_basename = File.basename(params[:web_root_overlay_bundle][:s3_url])
    bundle_path = params[:dir]+"/"+bundle_basename
  
    ruby_block "download webroot overlay bundle for #{app_name}" do
      block do
        InstanceMetadata.wait_for_instance_IAM_metadata_to_be_available
        env = {}
        if !(params[:web_root_overlay_bundle][:aws_access_key_id].nil?) && !(params[:web_root_overlay_bundle][:aws_secret_access_key].nil?)
          env = {
            "AWS_ACCESS_KEY_ID" => params[:web_root_overlay_bundle][:aws_access_key_id],
            "AWS_SECRET_ACCESS_KEY" => params[:web_root_overlay_bundle][:aws_secret_access_key]
          }  
        end
        shell = Mixlib::ShellOut.new("aws --region #{params[:web_root_overlay_bundle][:region]} s3 cp #{params[:web_root_overlay_bundle][:s3_url]} #{params[:dir]}", :env => env)
        result= shell.run_command
        if result.exitstatus != 0
          raise "Failed to download webroot overlay bundle from #{params[:web_root_overlay_bundle][:s3_url]}\nSTDERR:\n"+shell.stderr+"\nSTDOUT:\n"+shell.stdout
        end
      end
      not_if { File.exists?("#{bundle_path}") }
      notifies :run, "execute[open webroot overlay bundle for #{app_name}]", :immediately
    end
  
    execute "open webroot overlay bundle for #{app_name}" do
      cwd params[:docroot]
      command "tar xvzf #{bundle_path}"
      action :nothing
      notifies :run, "execute[fix wordpress dir owner and permissions for #{params[:docroot]}]", :immediately
    end
  
    execute "fix wordpress dir owner and permissions for #{params[:docroot]}" do
      user 'root'
      cwd params[:docroot]
      command <<-EOH
        chown #{node[:apache][:user]}:#{node[:apache][:group]} .
        chown -R #{node[:apache][:user]}:#{node[:apache][:group]} *
        find . -type d -exec chmod 755 {} \\;
        find . -type f -exec chmod 644 {} \\;
      EOH
      action :nothing
      notifies :run, "execute[protect #{app_name} webroot bundle from being read]", :immediately
    end
  
    execute "protect #{app_name} webroot bundle from being read" do
      command "chmod 000 #{bundle_path}"
      action :nothing
    end

  end

end
