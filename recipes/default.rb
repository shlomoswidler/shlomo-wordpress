wordpress_site node['wordpress']['app_name'] do
  repourl         node['wordpress']['repourl']
  version         node['wordpress']['version']
  dir             node['wordpress']['dir']
  server_aliases  node['wordpress']['server_aliases']
  fqdn            node['wordpress']['fqdn']
  db              node['wordpress']['db']
  table_prefix    node['wordpress']['table_prefix']
  languages       node['wordpress']['languages']
  wp_config_extras node['wordpress']['wp_config_extras']
  keys            node['wordpress']['keys']
  web_root_overlay_bundle node['wordpress']['web_root_overlay_bundle']
  admin_ips       node['wordpress']['admin_ips']
end
