#!/bin/bash

source setup/functions.sh

source /etc/mailinabox.conf


#source setup/ssl.sh             #set up ssl certs in $STORAGE_USER/ssl/ folder
#source setup/dns-local.sh	 #set up local dns server for local services , recursive
source setup/dns.sh		 #set up public dns server for public services , install nsd and zones etc
				 # nsd: The non-recursive nameserver that publishes our DNS records 
				 # where zones are done using tools/dns_update which calls to
				 #  curl -s -d $POSTDATA --user $(</var/lib/mailinabox/api.key): http://127.0.0.1:10222/dns/update
				 #  which basically calls the management/dns_update.py do_dns_update() function 
				 #  and http://127.0.0.1:10222 is a python flask app in /management/daemon.py
				 #
				 #
				 # $STORAGE_ROOT/dns/dnssec/$KSK.ds has the keys for signing the zones and the keys are rotated
				 # /home/user-data/dns/dnssec/


