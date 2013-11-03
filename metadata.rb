name             "shlomo-wordpress"
maintainer       "Shlomo Swidler"
maintainer_email "shlomo.swidler@orchestratus.com"
license          "Apache 2.0"
description      "Installs/Configures WordPress"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"

recipe "WordPress", "Installs and configures WordPress, and optionally the MySQL database it will use"

depends "wordpress", ">= 1.2.1"

%w{ debian ubuntu }.each do |os|
  supports os
end

attribute "WordPress/db/host",
  :display_name => "WordPress MySQL hostname",
  :description => "Name of the host on which MySQL is running.",
  :default => "localhost"

attribute "WordPress/server_aliases",
  :display_name => "WordPress Server Aliases",
  :description => "WordPress Server Aliases",
  :default => "FQDN"
