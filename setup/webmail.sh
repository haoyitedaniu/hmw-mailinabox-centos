#!/bin/bash
# Webmail with Roundcube
# ----------------------

source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

# ### Installing Roundcube

# We install Roundcube from sources, rather than from Ubuntu, because:
#
# 1. Ubuntu's `roundcube-core` package has dependencies on Apache & MySQL, which we don't want.
#
# 2. The Roundcube shipped with Ubuntu is consistently out of date.
#
# 3. It's packaged incorrectly --- it seems to be missing a directory of files.
#
# So we'll use apt-get to manually install the dependencies of roundcube that we know we need,
# and then we'll manually install roundcube from source.

# These dependencies are from `apt-cache showpkg roundcube-core`.

echo "installing php remi-${PHP_VER} ..."

 dnf install https://rpms.remirepo.net/enterprise/remi-release-8.rpm
 dnf module reset php
 dnf module enable php:remi-${PHP_VER} #8.0

 dnf install php php-common php-cli php-mbstring 
 dnf install php-gd php-pspell php-imap

 dnf install php-sqlite3
 dnf install php-intl
 dnf install php-curl

echo "installing web-assets-filesystem..." 

wget -O /tmp/web-assets-filesystem.rpm https://rpmfind.net/linux/centos/8-stream/PowerTools/x86_64/os/Packages/web-assets-filesystem-5-7.el8.noarch.rpm 
rpm -i /tmp/web-assets-filesystem.rpm
rm -f  /tmp/web-assets-filesystem.rpm

echo "installing libjs-jquery libjs-jquery-mousewhell"
wget -O /tmp/js-jquery.rpm https://rpmfind.net/linux/epel/8/Everything/x86_64/Packages/j/js-jquery-3.6.0-1.el8.noarch.rpm
rpm -i /tmp/js-jquery.rpm
rm -f /tmp/js-jquery.rpm

wget -O /tmp/js-jquery-mousewheel.rpm https://rpmfind.net/linux/epel/8/Everything/x86_64/Packages/j/js-jquery-mousewheel-3.1.13-1.el8.noarch.rpm
rpm -i /tmp/js-jquery-mousewheel.rpm
rm -f /tmp/js-jquery-mousewheel.rpm 

echo "installing libmagic1 ..."
wget -O /tmp/file-magic.rpm 
https://rpmfind.net/linux/opensuse/distribution/leap/15.4/repo/oss/noarch/file-magic-5.32-7.14.1.noarch.rpm
rpm -i /tmp/file-magic.rpm
rm -f /tmp/file-magic.rpm

wget -O /tmp/file-magic.rpm wget -O /tmp/file-magic.rpm https://rpmfind.net/linux/opensuse/tumbleweed/repo/oss/noarch/file-magic-5.43-1.1.noarch.rpm
rpm -i /tmp/file-magic.rpm
rm -f /tmp/file-magic.rpm 


wget -O /tmp/libmagic1.rpm   https://rpmfind.net/linux/opensuse/tumbleweed/repo/oss/x86_64/libmagic1-5.43-1.1.x86_64.rpm 
rpm -i /tmp/libmagic1.rpm
rm -f  /tmp/libmagic1.rpm

echo "Installing Roundcube (webmail)..."

#yum install \
#	dbconfig-common \
#	php${PHP_VER}-cli php${PHP_VER}-sqlite3 php${PHP_VER}-intl php${PHP_VER}-common php${PHP_VER}-curl \
#	\#libjs-jquery  \
#	\#libjs-jquery-mousewheel \ 
#	\ #libmagic1 

# Install Roundcube from source if it is not already present or if it is out of date.
# Combine the Roundcube version number with the commit hash of plugins to track
# whether we have the latest version of everything.
# For the latest versions, see:
#   https://github.com/roundcube/roundcubemail/releases
#   https://github.com/mfreiholz/persistent_login/commits/master
#   https://github.com/stremlau/html5_notifier/commits/master
#   https://github.com/mstilkerich/rcmcarddav/releases
# The easiest way to get the package hashes is to run this script and get the hash from
# the error message.
VERSION=1.6.0
HASH=fd84b4fac74419bb73e7a3bcae1978d5589c52de
PERSISTENT_LOGIN_VERSION=bde7b6840c7d91de627ea14e81cf4133cbb3c07a # version 5.2
HTML5_NOTIFIER_VERSION=68d9ca194212e15b3c7225eb6085dbcf02fd13d7 # version 0.6.4+
CARDDAV_VERSION=4.4.3
CARDDAV_HASH=74f8ba7aee33e78beb9de07f7f44b81f6071b644

UPDATE_KEY=$VERSION:$PERSISTENT_LOGIN_VERSION:$HTML5_NOTIFIER_VERSION:$CARDDAV_VERSION

# paths that are often reused.
RCM_DIR=/usr/local/lib/roundcubemail
RCM_PLUGIN_DIR=${RCM_DIR}/plugins
RCM_CONFIG=${RCM_DIR}/config/config.inc.php

needs_update=0 #NODOC
if [ ! -f /usr/local/lib/roundcubemail/version ]; then
	# not installed yet #NODOC
	needs_update=1 #NODOC
elif [[ "$UPDATE_KEY" != $(cat /usr/local/lib/roundcubemail/version) ]]; then
	# checks if the version is what we want
	needs_update=1 #NODOC
fi
if [ $needs_update == 1 ]; then
  # if upgrading from 1.3.x, clear the temp_dir
  if [ -f /usr/local/lib/roundcubemail/version ]; then
    if [ "$(cat /usr/local/lib/roundcubemail/version | cut -c1-3)" == '1.3' ]; then
      find /var/tmp/roundcubemail/ -type f ! -name 'RCMTEMP*' -delete
    fi
  fi

	# install roundcube
	wget_verify \
		https://github.com/roundcube/roundcubemail/releases/download/$VERSION/roundcubemail-$VERSION-complete.tar.gz \
		$HASH \
		/tmp/roundcube.tgz
	tar -C /usr/local/lib --no-same-owner -zxf /tmp/roundcube.tgz
	rm -rf /usr/local/lib/roundcubemail
	mv /usr/local/lib/roundcubemail-$VERSION/ $RCM_DIR
	rm -f /tmp/roundcube.tgz

	# install roundcube persistent_login plugin
	git_clone https://github.com/mfreiholz/Roundcube-Persistent-Login-Plugin.git $PERSISTENT_LOGIN_VERSION '' ${RCM_PLUGIN_DIR}/persistent_login

	# install roundcube html5_notifier plugin
	git_clone https://github.com/kitist/html5_notifier.git $HTML5_NOTIFIER_VERSION '' ${RCM_PLUGIN_DIR}/html5_notifier

	# download and verify the full release of the carddav plugin
	wget_verify \
		https://github.com/mstilkerich/rcmcarddav/releases/download/v${CARDDAV_VERSION}/carddav-v${CARDDAV_VERSION}.tar.gz \
		$CARDDAV_HASH \
		/tmp/carddav.tar.gz

	# unzip and cleanup
	tar -C ${RCM_PLUGIN_DIR} -zxf /tmp/carddav.tar.gz
	rm -f /tmp/carddav.tar.gz

	# record the version we've installed
	echo $UPDATE_KEY > ${RCM_DIR}/version
fi

# ### Configuring Roundcube


# Generate a secret key of PHP-string-safe characters appropriate
# for the cipher algorithm selected below.
SECRET_KEY=$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 | sed s/=//g)

# Create a configuration file.
#
# For security, temp and log files are not stored in the default locations
# which are inside the roundcube sources directory. We put them instead
# in normal places.
cat > $RCM_CONFIG <<EOF;
<?php
/*
 * Do not edit. Written by Mail-in-a-Box. Regenerated on updates.
 */
\$config = array();
\$config['log_dir'] = '/var/log/roundcubemail/';
\$config['temp_dir'] = '/var/tmp/roundcubemail/';
\$config['db_dsnw'] = 'sqlite:///$STORAGE_ROOT/mail/roundcube/roundcube.sqlite?mode=0640';
\$config['imap_host'] = 'ssl://localhost:993';
\$config['imap_conn_options'] = array(
  'ssl'         => array(
     'verify_peer'  => false,
     'verify_peer_name'  => false,
   ),
 );
\$config['imap_timeout'] = 15;
\$config['smtp_host'] = 'tls://127.0.0.1';
\$config['smtp_conn_options'] = array(
  'ssl'         => array(
     'verify_peer'  => false,
     'verify_peer_name'  => false,
   ),
 );
\$config['support_url'] = 'https://mailinabox.email/';
\$config['product_name'] = '$PRIMARY_HOSTNAME Webmail';
\$config['cipher_method'] = 'AES-256-CBC'; # persistent login cookie and potentially other things
\$config['des_key'] = '$SECRET_KEY'; # 37 characters -> ~256 bits for AES-256, see above
\$config['plugins'] = array('html5_notifier', 'archive', 'zipdownload', 'password', 'managesieve', 'jqueryui', 'persistent_login', 'carddav');
\$config['skin'] = 'elastic';
\$config['login_autocomplete'] = 2;
\$config['login_username_filter'] = 'email';
\$config['password_charset'] = 'UTF-8';
\$config['junk_mbox'] = 'Spam';
/* ensure roudcube session id's aren't leaked to other parts of the server */
\$config['session_path'] = '/mail/';
/* prevent CSRF, requires php 7.3+ */
\$config['session_samesite'] = 'Strict';
?>
EOF

# Configure CardDav
cat > ${RCM_PLUGIN_DIR}/carddav/config.inc.php <<EOF;
<?php
/* Do not edit. Written by Mail-in-a-Box. Regenerated on updates. */
\$prefs['_GLOBAL']['hide_preferences'] = true;
\$prefs['_GLOBAL']['suppress_version_warning'] = true;
\$prefs['ownCloud'] = array(
	 'name'         =>  'ownCloud',
	 'username'     =>  '%u', // login username
	 'password'     =>  '%p', // login password
	 'url'          =>  'https://${PRIMARY_HOSTNAME}/cloud/remote.php/dav/addressbooks/users/%u/contacts/',
	 'active'       =>  true,
	 'readonly'     =>  false,
	 'refresh_time' => '02:00:00',
	 'fixed'        =>  array('username','password'),
	 'preemptive_auth' => '1',
	 'hide'        =>  false,
);
?>
EOF

# Create writable directories.
mkdir -p /var/log/roundcubemail /var/tmp/roundcubemail $STORAGE_ROOT/mail/roundcube
chown -R root.nginx /var/log/roundcubemail /var/tmp/roundcubemail $STORAGE_ROOT/mail/roundcube

# Ensure the log file monitored by fail2ban exists, or else fail2ban can't start.
sudo -u nginx touch /var/log/roundcubemail/errors.log

# Password changing plugin settings
# The config comes empty by default, so we need the settings
# we're not planning to change in config.inc.dist...
cp ${RCM_PLUGIN_DIR}/password/config.inc.php.dist \
	${RCM_PLUGIN_DIR}/password/config.inc.php

tools/editconf.py ${RCM_PLUGIN_DIR}/password/config.inc.php \
	"\$config['password_minimum_length']=8;" \
	"\$config['password_db_dsn']='sqlite:///$STORAGE_ROOT/mail/users.sqlite';" \
	"\$config['password_query']='UPDATE users SET password=%D WHERE email=%u';" \
	"\$config['password_dovecotpw']='/usr/bin/doveadm pw';" \
	"\$config['password_dovecotpw_method']='SHA512-CRYPT';" \
	"\$config['password_dovecotpw_with_method']=true;"

# so PHP can use doveadm, for the password changing plugin
usermod -a -G dovecot nginx

# set permissions so that PHP can use users.sqlite
# could use dovecot instead of nginx, but not sure it matters
chown root.nginx $STORAGE_ROOT/mail
chmod 775 $STORAGE_ROOT/mail
chown root.nginx $STORAGE_ROOT/mail/users.sqlite
chmod 664 $STORAGE_ROOT/mail/users.sqlite

# Fix Carddav permissions:
chown -f -R root.nginx ${RCM_PLUGIN_DIR}/carddav
# root.nginx need all permissions, others only read
chmod -R 774 ${RCM_PLUGIN_DIR}/carddav

# Run Roundcube database migration script (database is created if it does not exist)
php$PHP_VER ${RCM_DIR}/bin/updatedb.sh --dir ${RCM_DIR}/SQL --package roundcube
chown nginx:nginx $STORAGE_ROOT/mail/roundcube/roundcube.sqlite
chmod 664 $STORAGE_ROOT/mail/roundcube/roundcube.sqlite

# Enable PHP modules.
#phpenmod -v $PHP_VER imap
phpenmod imap

#restart_service php$PHP_VER-fpm
restart_serice php-fpm

