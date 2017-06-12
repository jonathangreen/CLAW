#!/bin/bash
echo "Setup database for Drupal"
mysql -u root -e 'create database drupal;'
mysql -u root -e "GRANT ALL PRIVILEGES ON drupal.* To 'drupal'@'127.0.0.1' IDENTIFIED BY 'drupal';"

$SCRIPT_DIR/travis_setup_php.sh

echo "Install utilities needed for testing"
mkdir /opt/utils
cd /opt/utils
composer require squizlabs/php_codesniffer ^2.9
composer require drupal/coder
composer require sebastian/phpcpd
sudo ln -s /opt/utils/vendor/bin/phpcs /usr/bin/phpcs
sudo ln -s /opt/utils/vendor/bin/phpcpd /usr/bin/phpcpd
phpenv rehash
phpcs --config-set installed_paths /opt/utils/vendor/drupal/coder/coder_sniffer

echo "Composer install drupal site"
cd /opt
git clone https://github.com/Islandora-CLAW/drupal-project.git drupal
cd drupal

if [[ $RELEASE = development ]]; then 
  # the drupal 8.4.x branch has some dependancy conflicts with
  # console and composer, so we just don't install them if we 
  # are working on the development branch. 
  # Should probably be reevaluated for 8.5 when doing the update
  # https://github.com/drupal-composer/drupal-project/pull/270
  composer --verbose remove --no-update drupal/console 
  composer --verbose remove --no-update drush/drush
  composer --verbose require --no-update drupal/core:8.4.x-dev 
fi

composer install

echo "Setup Drush"
sudo ln -s /opt/drupal/vendor/bin/drush /usr/bin/drush
phpenv rehash

echo "Drush setup drupal site"
cd web
drush si --db-url=mysql://drupal:drupal@127.0.0.1/drupal --yes
drush runserver 127.0.0.1:8282 &
until curl -s 127.0.0.1:8282; do true; done > /dev/null
echo "Enable simpletest module"
drush --uri=127.0.0.1:8282 en -y simpletest

echo "Setup ActiveMQ"
cd /opt
wget "http://archive.apache.org/dist/activemq/5.14.3/apache-activemq-5.14.3-bin.tar.gz"
tar -xzf apache-activemq-5.14.3-bin.tar.gz
apache-activemq-5.14.3/bin/activemq start
