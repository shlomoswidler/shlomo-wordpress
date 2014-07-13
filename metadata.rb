name             "shlomo-wordpress"
maintainer       "Shlomo Swidler"
maintainer_email "shlomo.swidler@orchestratus.com"
license          "Apache 2.0"
description      "Installs/Configures WordPress"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"

recipe "WordPress", "Installs and configures WordPress, and optionally the MySQL database it will use"

depends "mysql", ">= 1.0.5"
depends "awscli", ">= 0.2.0"


%w{ debian ubuntu }.each do |os|
  supports os
end

attribute "WordPress/db/host",
  :display_name => "WordPress MySQL hostname",
  :description => "Name of the host on which MySQL is running.",
  :type => "string",
  :default => "localhost"

attribute "WordPress/wp_config_extras",
  :display_name => "Extra wp-config.php entries",
  :description => "hash of option name and value to place into wp-config.php, e.g. { 'ENABLE_CACHE' : 'false' }",
  :type => "string",
  :default => nil

attribute "WordPress/web_root_overlay_bundle/s3_url",
  :display_name => "webroot overlay bundle",
  :description => "S3 URL (s3://bucket/filename.tar.gz) of tarball to unpack into the wordpress root dir.",
  :type => "string",
  :required => "optional",
  :default => nil
  
attribute "WordPress/web_root_overlay_bundle/region",
  :display_name => "region",
  :description => "AWS region name in which the S3 bucket containing the webroot overlay bundle is located.",
  :type => "string",
  :required => "optional",
  :default => nil
  
attribute "WordPress/web_root_overlay_bundle/aws_access_key_id",
  :display_name => "AWS access key id",
  :description => "AWS access key id to use for accessing the specified root dir tarball. If not specified, the credentials associated with the instance's IAM Role, if any, will be used.",
  :type => "string",
  :required => "recommended",
  :default => nil

attribute "WordPress/web_root_overlay_bundle/aws_secret_access_key",
  :display_name => "AWS secret access key",
  :description => "AWS secret access key to use for accessing the specified root dir tarball. If not specified, the credentials associated with the instance's IAM Role, if any, will be used.",
  :type => "string",
  :required => "recommended",
  :default => nil

attribute "WordPress/admin_ips",
  :display_name => "Admin IPs",
  :description => "Array of IP address CIDRs to allow access to the admin/login area",
  :type => "array",
  :required => "optional",
  :default => "[ 'all' ]"

attribute "WordPress/version",
  :display_name => "WordPress download version",
  :description => "Version of WordPress to download from the WordPress site or 'latest' for the current release.",
  :default => "latest"

attribute "WordPress/checksum",
  :display_name => "WordPress tarball checksum",
  :description => "Checksum of the tarball for the version specified.",
  :default => ""

attribute "WordPress/dir",
  :display_name => "WordPress installation directory",
  :description => "Location to place WordPress files.",
  :default => "/var/www/wordpress"

attribute "WordPress/db/database",
  :display_name => "WordPress MySQL database",
  :description => "WordPress will use this MySQL database to store its data.",
  :default => "wordpressdb"

attribute "WordPress/db/user",
  :display_name => "WordPress MySQL user",
  :description => "WordPress will connect to MySQL using this user.",
  :default => "wordpressuser"

attribute "WordPress/db/password",
  :display_name => "WordPress MySQL password",
  :description => "Password for the WordPress MySQL user.",
  :default => "randomly generated"

attribute "WordPress/keys/auth",
  :display_name => "WordPress auth key",
  :description => "WordPress auth key.",
  :default => "randomly generated"

attribute "WordPress/keys/secure_auth",
  :display_name => "WordPress secure auth key",
  :description => "WordPress secure auth key.",
  :default => "randomly generated"

attribute "WordPress/keys/logged_in",
  :display_name => "WordPress logged-in key",
  :description => "WordPress logged-in key.",
  :default => "randomly generated"

attribute "WordPress/keys/nonce",
  :display_name => "WordPress nonce key",
  :description => "WordPress nonce key.",
  :default => "randomly generated"

attribute "WordPress/server_aliases",
  :display_name => "WordPress Server Aliases",
  :description => "WordPress Server Aliases",
  :default => "FQDN"

attribute "WordPress/languages/lang",
  :display_name => "WordPress WPLANG configulation value",
  :description => "WordPress WPLANG configulation value",
  :default => ""

attribute "WordPress/languages/version",
  :display_name => "Version of WordPress translation file",
  :description => "Version of WordPress translation file",
  :default => ""

attribute "WordPress/languages/projects",
  :display_name => "WordPress translation projects",
  :description => "WordPress translation projects",
  :type => "array",
  :default => ["main", "admin", "admin/network", "cc"]
