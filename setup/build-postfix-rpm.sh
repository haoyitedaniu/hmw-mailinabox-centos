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

dnf group install "Development Tools"
dnf group install "RPM Development Tools"

sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-PowerTools.repo 

rpmdev-setuptree

dnf download --source postfix

#dnf builddep --nobest postfix-X.Y.Z-N.el8.src.rpm
#rpmbuild -ra postfix-X.Y.Z-N.el8.src.rpm
