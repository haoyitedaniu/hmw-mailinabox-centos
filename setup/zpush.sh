#!/bin/bash
#
# 
# Z-Push: The Microsoft Exchange protocol server
# ----------------------------------------------
#
# Mostly for use on iOS which doesn't support IMAP IDLE.
#
# Although Ubuntu ships Z-Push (as d-push) it has a dependency on Apache
# so we won't install it that way.
#
# Thanks to http://frontender.ch/publikationen/push-mail-server-using-nginx-and-z-push.html.
# https://think.unblog.ch/en/how-to-install-z-push/   
# https://zignar.net/2012/04/14/z-push/

source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

# Prereqs.

echo "Installing Z-Push (Exchange/ActiveSync server)..."

 dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm
 dnf -y module reset php
 dnf -y module enable php:remi-${PHP_VER} #8.0
 dnf -y install php-soap php-imap  php-xml

 ##dnf -y install libawl-php
 ##dnf -y install devel/php-libawl

 #wget_verify "https://gitlab.com/davical-project/awl/-/archive/r0.63/awl-r0.63.zip" ea4df6905a5821e60a8e6e37cfa4c01af2ff4e37 /tmp/libawl-php.zip
 #unzip -q /tmp/libawl-php.zip -d /tmp/libawl-php 

#yum install \
#       php${PHP_VER}-soap php${PHP_VER}-imap libawl-php php$PHP_VER-xml

#phpenmod -v $PHP_VER imap

# Copy Z-Push into place.
VERSION=2.6.2
TARGETHASH=f0e8091a8030e5b851f5ba1f9f0e1a05b8762d80
needs_update=0 #NODOC
if [ ! -f /usr/local/lib/z-push/version ]; then
	needs_update=1 #NODOC
elif [[ $VERSION != $(cat /usr/local/lib/z-push/version) ]]; then
	# checks if the version
	needs_update=1 #NODOC
fi
if [ $needs_update == 1 ]; then
	# Download
	wget_verify "https://github.com/Z-Hub/Z-Push/archive/refs/tags/$VERSION.zip" $TARGETHASH /tmp/z-push.zip

	# Extract into place /usr/local/lib/z-push/ 
	rm -rf /usr/local/lib/z-push /tmp/z-push
	unzip -q /tmp/z-push.zip -d /tmp/z-push
	mv /tmp/z-push/*/src /usr/local/lib/z-push   #install in /usr/local/lib/z-push https://zignar.net/2012/04/14/z-push/
	rm -rf /tmp/z-push.zip /tmp/z-push

	rm -f /usr/sbin/z-push-{admin,top}
	echo $VERSION > /usr/local/lib/z-push/version
fi

# Configure default config.
sed -i "s^define('TIMEZONE', .*^define('TIMEZONE', '$(cat /etc/timezone)');^" /usr/local/lib/z-push/config.php
sed -i "s/define('BACKEND_PROVIDER', .*/define('BACKEND_PROVIDER', 'BackendCombined');/" /usr/local/lib/z-push/config.php
sed -i "s/define('USE_FULLEMAIL_FOR_LOGIN', .*/define('USE_FULLEMAIL_FOR_LOGIN', true);/" /usr/local/lib/z-push/config.php
sed -i "s/define('LOG_MEMORY_PROFILER', .*/define('LOG_MEMORY_PROFILER', false);/" /usr/local/lib/z-push/config.php
sed -i "s/define('BUG68532FIXED', .*/define('BUG68532FIXED', false);/" /usr/local/lib/z-push/config.php
sed -i "s/define('LOGLEVEL', .*/define('LOGLEVEL', LOGLEVEL_ERROR);/" /usr/local/lib/z-push/config.php

# Configure BACKEND 
rm -f /usr/local/lib/z-push/backend/combined/config.php
cp conf/zpush/backend_combined.php /usr/local/lib/z-push/backend/combined/config.php

# Configure IMAP
rm -f /usr/local/lib/z-push/backend/imap/config.php
cp conf/zpush/backend_imap.php /usr/local/lib/z-push/backend/imap/config.php
sed -i "s%STORAGE_ROOT%$STORAGE_ROOT%" /usr/local/lib/z-push/backend/imap/config.php

# Configure CardDav
rm -f /usr/local/lib/z-push/backend/carddav/config.php
cp conf/zpush/backend_carddav.php /usr/local/lib/z-push/backend/carddav/config.php

# Configure CalDav
rm -f /usr/local/lib/z-push/backend/caldav/config.php
cp conf/zpush/backend_caldav.php /usr/local/lib/z-push/backend/caldav/config.php

# Configure Autodiscover
rm -f /usr/local/lib/z-push/autodiscover/config.php
cp conf/zpush/autodiscover_config.php /usr/local/lib/z-push/autodiscover/config.php
sed -i "s/PRIMARY_HOSTNAME/$PRIMARY_HOSTNAME/" /usr/local/lib/z-push/autodiscover/config.php
sed -i "s^define('TIMEZONE', .*^define('TIMEZONE', '$(cat /etc/timezone)');^" /usr/local/lib/z-push/autodiscover/config.php

# Some directories it will use.

mkdir -p /var/log/z-push
mkdir -p /var/lib/z-push
chmod 750 /var/log/z-push
chmod 750 /var/lib/z-push
chown root:nginx /var/log/z-push
chown root:nginx /var/lib/z-push

chown -R root:root /usr/local/lib/z-push
chmod 775 /usr/local/lib/z-push

# Add log rotation

cat > /etc/logrotate.d/z-push <<EOF;
/var/log/z-push/*.log {
	weekly
	missingok
	rotate 52
	compress
	delaycompress
        create root nginx
	notifempty
}
EOF

# Restart service.
# php-fpm was installed along with web.sh

restart_service php-fpm

# Fix states after upgrade

hide_output php /usr/local/lib/z-push/z-push-admin.php -a fixstates
