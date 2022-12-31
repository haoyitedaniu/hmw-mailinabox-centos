#!/bin/bash

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

source setup/functions.sh
source setup/system.sh 

dnf -y group install "Development Tools"
dnf -y group install "RPM Development Tools"

sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-Stream-PowerTools.repo 

rpmdev-setuptree

dnf -y download --source postfix

dnf -y builddep --nobest postfix-3.5.8-4.el8.src.rpm  #postfix-X.Y.Z-N.el8.src.rpm
rpmbuild -ra postfix-3.5.8-4.el8.src.rpm           #  postfix-X.Y.Z-N.el8.src.rpm


#the end results are here
#Wrote: /root/rpmbuild/SRPMS/postfix-3.5.8-4.el8.src.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-perl-scripts-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-mysql-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-pgsql-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-sqlite-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-cdb-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-ldap-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-lmdb-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-pcre-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-debugsource-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-debuginfo-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-mysql-debuginfo-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-pgsql-debuginfo-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-sqlite-debuginfo-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-cdb-debuginfo-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-ldap-debuginfo-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-lmdb-debuginfo-3.5.8-4.el8.x86_64.rpm
#Wrote: /root/rpmbuild/RPMS/x86_64/postfix-pcre-debuginfo-3.5.8-4.el8.x86_64.rpm

#install postfix, pcre, sqlite
yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-3.5.8-4.el8.x86_64.rpm 
yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-perl-scripts-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-mysql-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-pgsql-3.5.8-4.el8.x86_64.rpm
yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-sqlite-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-cdb-3.5.8-4.el8.x86_64.rpm 
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-ldap-3.5.8-4.el8.x86_64.rpm 
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-lmdb-3.5.8-4.el8.x86_64.rpm 
yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-pcre-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-debugsource-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-debuginfo-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-mysql-debuginfo-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-pgsql-debuginfo-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-sqlite-debuginfo-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-cdb-debuginfo-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-ldap-debuginfo-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-lmdb-debuginfo-3.5.8-4.el8.x86_64.rpm
#yum --assumeyes --quiet install /root/rpmbuild/RPMS/x86_64/postfix-pcre-debuginfo-3.5.8-4.el8.x86_64.rpm

#install postfix-sqlite
#yum --assumeyes --quiet install root/rpmbuild/RPMS/x86_64/postfix-3.5.8-4.el8.x86_64.rpm


