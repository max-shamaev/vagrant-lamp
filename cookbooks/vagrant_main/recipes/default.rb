include_recipe "apt"
include_recipe "build-essential"
include_recipe "git"
# problem with git status on every directory operation
#include_recipe "oh-my-zsh"
include_recipe "apache2"
include_recipe "apache2::mod_rewrite"
include_recipe "apache2::mod_ssl"
include_recipe "mysql::server"

# include php5-oldstable repository
bash "psproperties" do
  code "sudo apt-get -y install python-software-properties"
end
bash "php54" do
  code "sudo add-apt-repository ppa:ondrej/php5-oldstable"
end

include_recipe "php"
include_recipe "php::module_mysql"
include_recipe "php::module_apc"
Ginclude_recipe "php::module_curl"
include_recipe "apache2::mod_php5"
include_recipe "composer"
include_recipe "phing"
include_recipe "php-box"
include_recipe "networking_basic"
include_recipe "memcached"
include_recipe "php::module_memcache"

# Install packages
%w{ debconf vim screen tmux mc subversion curl make g++ libsqlite3-dev graphviz libxml2-utils lynx links}.each do |a_package|
  package a_package
end

# Install ruby gems
%w{ rake mailcatcher }.each do |a_gem|
  gem_package a_gem
end

# Generate selfsigned ssl
execute "make-ssl-cert" do
  command "make-ssl-cert generate-default-snakeoil --force-overwrite"
  ignore_failure true
  action :nothing
end

# Initialize sites data bag
sites = []
begin
  sites = data_bag("sites")
rescue
  puts "Sites data bag is empty"
end

# Configure sites
sites.each do |name|
  site = data_bag_item("sites", name)
  docroot_var = site["docroot"]?site["docroot"]:"/vagrant/public/#{site["host"]}"

  # Add site to apache config
  web_app site["host"] do
    template "sites.conf.erb"
    server_name site["host"]
    server_aliases site["aliases"]
    docroot docroot_var
  end  

  # Add site info in /etc/hosts
  bash "hosts" do
    code "echo 127.0.0.1 #{site["host"]} #{site["aliases"].join(' ')} >> /etc/hosts"
  end

  bash "mkdir docroot" do
    code "mkdir -p #{docroot_var}"
  end

  bash "chmod docroot" do
    code "chmod 777 #{docroot_var}"
  end

  bash "chown docroot" do
    code "chown vagrant #{docroot_var}"
  end

  bash "chgrp docroot" do
    code "chgrp vagrant #{docroot_var}"
  end

end

# Disable default site
apache_site "default" do
  enable false  
end

# Install phpmyadmin
cookbook_file "/tmp/phpmyadmin.deb.conf" do
  source "phpmyadmin.deb.conf"
end
bash "debconf_for_phpmyadmin" do
  code "debconf-set-selections /tmp/phpmyadmin.deb.conf"
end
package "phpmyadmin"
#bash "phpmyadmin-fix" do
#  code "sudo perl -pi -e 's/\/\/\s*(\$cfg..Servers....i...AllowNoPassword.. = TRUE;)/$1/' /etc/phpmyadmin/config.inc.php"
#end

# Install Xdebug
php_pear "xdebug" do
  action :install
end
template "#{node['php']['ext_conf_dir']}/xdebug.ini" do
  source "xdebug.ini.erb"
  owner "root"
  group "root"
  mode "0644"
  action :create
  notifies :restart, resources("service[apache2]"), :delayed
end

# Install Webgrind
git "/var/www/webgrind" do
  repository 'git://github.com/jokkedk/webgrind.git'
  reference "master"
  action :sync
end
template "#{node[:apache][:dir]}/conf.d/webgrind.conf" do
  source "webgrind.conf.erb"
  owner "root"
  group "root"
  mode 0644
  action :create
  notifies :restart, resources("service[apache2]"), :delayed
end
template "/var/www/webgrind/config.php" do
  source "webgrind.config.php.erb"
  owner "root"
  group "root"
  mode 0644
  action :create
end

# Install php-xsl
package "php5-xsl" do
  action :install
end

# Setup MailCatcher
bash "mailcatcher" do
  code "mailcatcher --http-ip 0.0.0.0 --smtp-port 25"
  not_if "ps ax | grep -v grep | grep mailcatcher";
end
template "#{node['php']['ext_conf_dir']}/mailcatcher.ini" do
  source "mailcatcher.ini.erb"
  owner "root"
  group "root"
  mode "0644"
  action :create
  notifies :restart, resources("service[apache2]"), :delayed
end

# Fix deprecated php comments style in ini files
bash "deploy" do
  code "sudo perl -pi -e 's/(\s*)#/$1;/' /etc/php5/cli/conf.d/*ini"
  notifies :restart, resources("service[apache2]"), :delayed
end

# Upgrades
%w{apache2 php5 mysql-server}.each do |a_package|
  package a_package do
    action :upgrade
  end
end

