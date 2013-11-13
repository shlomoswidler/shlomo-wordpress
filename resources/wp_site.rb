actions :create
default_action :create

attribute :name, :kind_of => String, :name_attribute => true

attribute :fqdn, :kind_of => String, :required => true
attribute :repourl, :kind_of => String, :required => false
attribute :version, :kind_of => String, :default => "latest", :required => false
attribute :template, :kind_of => String, :default => "wordpress.conf.erb", :required => false
attribute :cookbook, :kind_of => [String, NilClass], :default => nil, :required => false
attribute :dir, :kind_of => String, :required => true
attribute :docroot, :kind_of => String, :default => "", :required => false
attribute :server_aliases, :kind_of => Array, :required => false
attribute :table_prefix, :kind_of [String, NilClass], :default => nil, :required => false
attribute :admin_ips, :kind_of [Array, NilClass], :default => [ "all" ], :required => false
attribute :wp_config_extras, :kind_of => [Hash, NilClass], :default => nil, :required => false
attribute :wp_config_auth_key, :kind_of => [String, NilClass], :default => nil, :required => false
attribute :wp_config_secure_auth_key, :kind_of => [String, NilClass], :default => nil, :required => false
attribute :wp_config_logged_in_key, :kind_of => [String, NilClass], :default => nil, :required => false
attribute :wp_config_nonce_key, :kind_of => [String, NilClass], :default => nil, :required => false
attribute :db_host, :kind_of => String, :default => "localhost", :required => false
attribute :db_user, :kind_of => String, :required => true
attribute :db_password, :kind_of => String, :required => true
attribute :db_database, :kind_of => String, :required => true
attribute :db_admin_user, :kind_of => String, :required => true
attribute :db_admin_password, :kind_of => String, :required => true

  

