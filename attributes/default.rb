#
# Author:: Barry Steinglass (<barry@opscode.com>)
# Author:: Koseki Kengo (<koseki@gmail.com>)
# Cookbook Name:: wordpress
# Attributes:: wordpress
#
# Copyright 2009-2013, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# General settings
default['wordpress'] = {}
node['wordpress'].each do |site, options|
  default['wordpress'][site] = {}
  default['wordpress'][site]['version'] = "latest"
  default['wordpress'][site]['checksum'] = ""
  default['wordpress'][site]['repourl'] = "http://wordpress.org/"
  default['wordpress'][site]['dir'] = "/var/www/wordpress"
  default='wordpress'][site]['db'] = {}
  default['wordpress'][site]['db']['database'] = "wordpressdb"
  default['wordpress'][site]['db']['user'] = "wordpressuser"
  default['wordpress'][site]['server_aliases'] = [node['fqdn']]
  default['wordpress'][site]['languages'] = {}
  default['wordpress'][site]['languages']['lang'] = ''
  default['wordpress'][site]['table_prefix'] = "wp_"
  default['wordpress'][site]['db']['host'] = "localhost"
  default['wordpress'][site]['wp_config_extras'] = {}
  default['wordpress'][site]['admin_ips'] = ["all"]
end
