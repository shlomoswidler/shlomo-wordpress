node['wordpress'].each do |app_name, options|
  wordpress_site app_name do
    repourl         options['repourl']
    version         options['version']
    dir             options['dir']
    server_aliases  options['server_aliases']
    fqdn            options['fqdn']
    db              options['db']
    table_prefix    options['table_prefix']
    languages       options['languages']
    wp_config_extras options['wp_config_extras']
    keys            options['keys']
    web_root_overlay_bundle options['web_root_overlay_bundle']
    admin_ips       options['admin_ips']
    ssl             options['ssl']
  end
end
