wordpress_site node['wordpress']['app_name'] do
  db              node['wordpress']['db']
  dir             node['wordpress']['dir']
  fqdn            node['wordpress']['fqdn']
  server_aliases  node['wordpress']['server_aliases']
  languages       node['wordpress']['languages']
  wp_config_extras node['wordpress']['wp_config_extras']
  table_prefix    node['wordpress']['table_prefix']
  web_root_overlay_bundle node['wordpress']['web_root_overlay_bundle']
  admin_ips       node['wordpress']['admin_ips']
end
