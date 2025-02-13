#!/bin/bash
#
# Postfix (SMTP)
# --------------
#
# Postfix handles the transmission of email between servers
# using the SMTP protocol. It is a Mail Transfer Agent (MTA).
#
# Postfix listens on port 25 (SMTP) for incoming mail from
# other servers on the Internet. It is responsible for very
# basic email filtering such as by IP address and greylisting,
# it checks that the destination address is valid, rewrites
# destinations according to aliases, and passses email on to
# another service for local mail delivery.
#
# The first hop in local mail delivery is to Spamassassin via
# LMTP. Spamassassin then passes mail over to Dovecot for
# storage in the user's mailbox.
#
# Postfix also listens on port 587 (SMTP+STARTLS) for
# connections from users who can authenticate and then sends
# their email out to the outside world. Postfix queries Dovecot
# to authenticate users.
#
# Address validation, alias rewriting, and user authentication
# is configured in a separate setup script mail-users.sh
# because of the overlap of this part with the Dovecot
# configuration.

source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

# ### Install packages.

# Install postfix's packages.
#
# * `postfix`: The SMTP server.
# * `postfix-pcre`: Enables header filtering.
# * `postgrey`: A mail policy service that soft-rejects mail the first time
#   it is received. Spammers don't usually try agian. Legitimate mail
#   always will.
# * `ca-certificates`: A trust store used to squelch postfix warnings about
#   untrusted opportunistically-encrypted connections.
#

echo "Installing Postfix (SMTP server)..."
# Neither CentOS nor EPEL repositories offer the pcre or sqlite plugins for postfix
# We have built these from source as follows and made them publicly available
# 1. Clean CentOS 8 install, add dev and rpm dev tool groups
#       a. yum group install "Development Tools"
#       b. yum group install "RPM Development Tools"
# 2. Enable PowerTools repository
#       a. sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-PowerTools.repo
# 3. Create rpmbuild tree as non-root user with `rpmdev-setuptree`
# 4. Download source RPM with `yum download --source postfix`
# 5. Install all dependencies needed to build with `yum builddep --nobest postfix-X.Y.Z-N.el8.src.rpm`
# 6. Build everything with `rpmbuild -ra postfix-X.Y.Z-N.el8.src.rpm`

#hide_output dig rpmfind.net
#wget http://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/postfix-3.5.8-4.el8.x86_64.rpm -O /tmp/postfix.rpm
##wget_verify https://kinibay.org/postfix-rpms/postfix-3.3.1-8.el8.brs.x86_64.rpm \
##    e0c30d0d0ef0514e74238ab619b0ba058ea18d8a /tmp/postfix.rpm
#hide_output yum --assumeyes --quiet install /tmp/postfix.rpm
#rm /tmp/postfix.rpm
##wget_verify https://kinibay.org/postfix-rpms/postfix-pcre-3.3.1-8.el8.brs.x86_64.rpm \
##    a6c943835b49c9e2d16429d43ebef6013d332c3b /tmp/postfix-pcre.rpm
#wget -O /tmp/postfix-pcre.rpm http://rpmfind.net/linux/centos/8-stream/AppStream/x86_64/os/Packages/postfix-pcre-3.5.8-4.el8.x86_64.rpm 
#hide_output yum --assumeyes --quiet install /tmp/postfix-pcre.rpm
#rm /tmp/postfix-pcre.rpm
##wget_verify https://kinibay.org/postfix-rpms/postfix-sqlite-3.3.1-8.el8.brs.x86_64.rpm \
##    e0d7fa789b11f10f02ece7d5e102d457af07a12c /tmp/postfix-sqlite.rpm
#wget -O /tmp/postfix-sqlite.rpm http://rpmfind.net/linux/centos/8-stream/AppStream/x86_64/os/Packages/postfix-sqlite-3.5.8-4.el8.x86_64.rpm
#hide_output yum --assumeyes --quiet install /tmp/postfix-sqlite.rpm
#rm /tmp/postfix-sqlite.rpm

#the above are now done with setup/build-and-install-postfix-rpm.sh and you may need to edit teh version number of it if it fails
source setup/build-and-install-postfix-rpm.sh

# Similary for postgrey, had to build our own package

#wget_verify https://kinibay.org/postgrey-rpms/postgrey-1.37-1.el8.brs.noarch.rpm \
#    de61cc869820bd8bd1ba3707331b9b503a9ff93b /tmp/postgrey.rpm

wget -O /tmp/postgrey.rpm http://rpmfind.net/linux/epel/8/Everything/x86_64/Packages/p/postgrey-1.37-9.el8.noarch.rpm 
hide_output yum --assumeyes --quiet install /tmp/postgrey.rpm
rm /tmp/postgrey.rpm

# Install certificate authority certs
hide_output yum --assumeyes --quiet install ca-certificates

#exit

# ### Basic Settings

# Set some basic settings...
#
# * Have postfix listen on all network interfaces.
# * Make outgoing connections on a particular interface (if multihomed) so that SPF passes on the receiving side.
# * Set our name (the Debian default seems to be "localhost" but make it our hostname).
# * Set the name of the local machine to localhost, which means xxx@localhost is delivered locally, although we don't use it.
# * Set the SMTP banner (which must have the hostname first, then anything).
tools/editconf.py /etc/postfix/main.cf \
	inet_interfaces=all \
	smtp_bind_address=$PRIVATE_IP \
	smtp_bind_address6=$PRIVATE_IPV6 \
	myhostname=$PRIMARY_HOSTNAME\
	smtpd_banner="\$myhostname ESMTP Hi, I'm a CentOS-Mail-in-a-Box" \
	mydestination=localhost

# Tweak some queue settings:
# * Inform users when their e-mail delivery is delayed more than 3 hours (default is not to warn).
# * Stop trying to send an undeliverable e-mail after 2 days (instead of 5), and for bounce messages just try for 1 day.
tools/editconf.py /etc/postfix/main.cf \
	delay_warning_time=3h \
	maximal_queue_lifetime=2d \
	bounce_queue_lifetime=1d

# ### Outgoing Mail

# Enable the 'submission' port 587 smtpd server and tweak its settings.
#
# * Enable authentication. It's disabled globally so that it is disabled on port 25,
#   so we need to explicitly enable it here.
# * Do not add the OpenDMAC Authentication-Results header. That should only be added
#   on incoming mail. Omit the OpenDMARC milter by re-setting smtpd_milters to the
#   OpenDKIM milter only. See dkim.sh.
# * Even though we dont allow auth over non-TLS connections (smtpd_tls_auth_only below, and without auth the client cant
#   send outbound mail), don't allow non-TLS mail submission on this port anyway to prevent accidental misconfiguration.
# * Require the best ciphers for incoming connections per http://baldric.net/2013/12/07/tls-ciphers-in-postfix-and-dovecot/.
#   By putting this setting here we leave opportunistic TLS on incoming mail at default cipher settings (any cipher is better than none).
# * Give it a different name in syslog to distinguish it from the port 25 smtpd server.
# * Add a new cleanup service specific to the submission service ('authclean')
#   that filters out privacy-sensitive headers on mail being sent out by
#   authenticated users.  By default Postfix also applies this to attached
#   emails but we turn this off by setting nested_header_checks empty.
tools/editconf.py /etc/postfix/master.cf -s -w \
	"submission=inet n       -       -       -       -       smtpd
	  -o smtpd_sasl_auth_enable=yes
	  -o syslog_name=postfix/submission
	  -o smtpd_milters=inet:127.0.0.1:8891
	  -o smtpd_tls_security_level=encrypt
	  -o smtpd_tls_ciphers=high -o smtpd_tls_exclude_ciphers=aNULL,DES,3DES,MD5,DES+MD5,RC4 -o smtpd_tls_mandatory_protocols=!SSLv2,!SSLv3
	  -o cleanup_service_name=authclean" \
	"authclean=unix  n       -       -       -       0       cleanup
	  -o header_checks=pcre:/etc/postfix/outgoing_mail_header_filters
	  -o nested_header_checks="

# Install the `outgoing_mail_header_filters` file required by the new 'authclean' service.
cp conf/postfix_outgoing_mail_header_filters /etc/postfix/outgoing_mail_header_filters

# Modify the `outgoing_mail_header_filters` file to use the local machine name and ip
# on the first received header line.  This may help reduce the spam score of email by
# removing the 127.0.0.1 reference.
sed -i "s/PRIMARY_HOSTNAME/$PRIMARY_HOSTNAME/" /etc/postfix/outgoing_mail_header_filters
sed -i "s/PUBLIC_IP/$PUBLIC_IP/" /etc/postfix/outgoing_mail_header_filters

# Enable TLS on these and all other connections (i.e. ports 25 *and* 587) and
# require TLS before a user is allowed to authenticate. This also makes
# opportunistic TLS available on *incoming* mail.
# Set stronger DH parameters, which via openssl tend to default to 1024 bits
# (see ssl.sh).
tools/editconf.py /etc/postfix/main.cf \
	smtpd_tls_security_level=may\
	smtpd_tls_auth_only=yes \
	smtpd_tls_cert_file=$STORAGE_ROOT/ssl/ssl_certificate.pem \
	smtpd_tls_key_file=$STORAGE_ROOT/ssl/ssl_private_key.pem \
	smtpd_tls_dh1024_param_file=$STORAGE_ROOT/ssl/dh2048.pem \
	smtpd_tls_protocols=\!SSLv2,\!SSLv3 \
	smtpd_tls_ciphers=medium \
	smtpd_tls_exclude_ciphers=aNULL,RC4 \
	smtpd_tls_received_header=yes

# Prevent non-authenticated users from sending mail that requires being
# relayed elsewhere. We don't want to be an "open relay". On outbound
# mail, require one of:
#
# * `permit_sasl_authenticated`: Authenticated users (i.e. on port 587).
# * `permit_mynetworks`: Mail that originates locally.
# * `reject_unauth_destination`: No one else. (Permits mail whose destination is local and rejects other mail.)
tools/editconf.py /etc/postfix/main.cf \
	smtpd_relay_restrictions=permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination


# ### DANE

# When connecting to remote SMTP servers, prefer TLS and use DANE if available.
#
# Prefering ("opportunistic") TLS means Postfix will use TLS if the remote end
# offers it, otherwise it will transmit the message in the clear. Postfix will
# accept whatever SSL certificate the remote end provides. Opportunistic TLS
# protects against passive easvesdropping (but not man-in-the-middle attacks).
# DANE takes this a step further:
#
# Postfix queries DNS for the TLSA record on the destination MX host. If no TLSA records are found,
# then opportunistic TLS is used. Otherwise the server certificate must match the TLSA records
# or else the mail bounces. TLSA also requires DNSSEC on the MX host. Postfix doesn't do DNSSEC
# itself but assumes the system's nameserver does and reports DNSSEC status. Thus this also
# relies on our local DNS server (see system.sh) and `smtp_dns_support_level=dnssec`.
#
# The `smtp_tls_CAfile` is superflous, but it eliminates warnings in the logs about untrusted certs,
# which we don't care about seeing because Postfix is doing opportunistic TLS anyway. Better to encrypt,
# even if we don't know if it's to the right party, than to not encrypt at all. Instead we'll
# now see notices about trusted certs. The CA file is provided by the package `ca-certificates`.
tools/editconf.py /etc/postfix/main.cf \
	smtp_tls_protocols=\!SSLv2,\!SSLv3 \
	smtp_tls_mandatory_protocols=\!SSLv2,\!SSLv3 \
	smtp_tls_ciphers=medium \
	smtp_tls_exclude_ciphers=aNULL,RC4 \
	smtp_tls_security_level=dane \
	smtp_dns_support_level=dnssec \
	smtp_tls_CAfile=/etc/ssl/certs/ca-bundle.crt \
	smtp_tls_loglevel=2

# ### Incoming Mail

# Pass any incoming mail over to a local delivery agent. Spamassassin
# will act as the LDA agent at first. It is listening on port 10025
# with LMTP. Spamassassin will pass the mail over to Dovecot after.
#
# In a basic setup we would pass mail directly to Dovecot by setting
# virtual_transport to `lmtp:unix:private/dovecot-lmtp`.
#
tools/editconf.py /etc/postfix/main.cf virtual_transport=lmtp:[127.0.0.1]:10025

# Who can send mail to us? Some basic filters.
#
# * `reject_non_fqdn_sender`: Reject not-nice-looking return paths.
# * `reject_unknown_sender_domain`: Reject return paths with invalid domains.
# * `reject_authenticated_sender_login_mismatch`: Reject if mail FROM address does not match the client SASL login
# * `reject_rhsbl_sender`: Reject return paths that use blacklisted domains.
# * `permit_sasl_authenticated`: Authenticated users (i.e. on port 587) can skip further checks.
# * `permit_mynetworks`: Mail that originates locally can skip further checks.
# * `reject_rbl_client`: Reject connections from IP addresses blacklisted in zen.spamhaus.org
# * `reject_unlisted_recipient`: Although Postfix will reject mail to unknown recipients, it's nicer to reject such mail ahead of greylisting rather than after.
# * `check_policy_service`: Apply greylisting using postgrey.
#
# Notes: #NODOC
# permit_dnswl_client can pass through mail from whitelisted IP addresses, which would be good to put before greylisting #NODOC
# so these IPs get mail delivered quickly. But when an IP is not listed in the permit_dnswl_client list (i.e. it is not #NODOC
# whitelisted) then postfix does a DEFER_IF_REJECT, which results in all "unknown user" sorts of messages turning into #NODOC
# "450 4.7.1 Client host rejected: Service unavailable". This is a retry code, so the mail doesn't properly bounce. #NODOC
tools/editconf.py /etc/postfix/main.cf \
	smtpd_sender_restrictions="reject_non_fqdn_sender,reject_unknown_sender_domain,reject_authenticated_sender_login_mismatch,reject_rhsbl_sender dbl.spamhaus.org" \
	smtpd_recipient_restrictions=permit_sasl_authenticated,permit_mynetworks,"reject_rbl_client zen.spamhaus.org",reject_unlisted_recipient,"check_policy_service inet:127.0.0.1:10023"

# Postfix connects to Postgrey on the 127.0.0.1 interface specifically. Ensure that
# Postgrey listens on the same interface (and not IPv6, for instance).
# A lot of legit mail servers try to resend before 300 seconds.
# As a matter of fact RFC is not strict about retry timer so postfix and
# other MTA have their own intervals. To fix the problem of receiving
# e-mails really latter, delay of greylisting has been set to
# 60 seconds (which is the default on CentOS).
tools/editconf.py /etc/sysconfig/postgrey \
	POSTGREY_OPTS=\"'--inet=127.0.0.1:10023 --delay=60'\"

# Increase the message size limit from 10MB to 128MB.
# The same limit is specified in nginx.conf for mail submitted via webmail and Z-Push.
tools/editconf.py /etc/postfix/main.cf \
	message_size_limit=134217728

# Allow the two SMTP ports in the firewall.

hide_output firewall-cmd --quiet --permanent --add-service=smtp
hide_output firewall-cmd --quiet --permanent --add-service=smtp-submission
hide_output systemctl --quiet reload firewalld

# Restart services

# postgrey is disabled by default, so enable and then start it, but first we need to
# create a new SELinux rule to allow /usr/bin/perl permission to bind to tcp socket 10023
semanage port -m -t postgrey_port_t -p tcp 10023
hide_output systemctl --quiet enable postgrey
hide_output systemctl --quiet start postgrey

# PERMISSIONS

# fix SELinux ACLs recursively on entire directory, strictly only need to
# fix permissions on outgoinng_mail_headers file copied from user space
restorecon -F -r /etc/postfix/

#****************** REMOVE ???? ****************************************************

# Postfix v3.2 from IUS has a minor SELinux bug where the postfix/sendmail process
# cannot read /etc/postfix/dynamicmaps.cf.d directory
# To workaround this bug, create a new SELinux rule granting postfix/sendmail
# permission to read this directory.
#cat > /tmp/my-newaliases.te << EOF;
#
#module my-newaliases 1.0;
#
#require {
#	type sendmail_t;
#	type postfix_etc_t;
#	class dir read;
#}
#
##============= sendmail_t ==============
#allow sendmail_t postfix_etc_t:dir read;
#EOF
#
#hide_output checkmodule -M -m -o /tmp/my-newaliases.mod /tmp/my-newaliases.te
#hide_output semodule_package -o /tmp/my-newaliases.pp -m /tmp/my-newaliases.mod
#hide_output semodule -i /tmp/my-newaliases.pp
#rm -f /tmp/my-newaliases.*
# **********************************************************************************


#   ***** START POSTGREY HERE AS WELL ???? **************
# start postfix and enable to auto-start after reboots
hide_output systemctl --quiet --now enable postfix
