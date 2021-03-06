#!/bin/bash

logfile=$(pwd)/bootstrap.log

install_debian () {
  log "Checking Operating System..."
  dist=$(lsb_release -sd)
  version=$(lsb_release -sr)
  animal=$(lsb_release -sc)

  [[ $dist =~ 'Ubuntu' ]] || die "Linux distro not supported"
  [[ $version =~ '12.04' || $version =~ '14.04' ]] || die "Ubuntu version not supported"

  log "Updating package lists..."
  apt-get -qq update | tee -a $logfile

  log "Upgrading/Removing existing packages..."

  # do not run upgrade in CI environment
  if [[ -z $TRAVIS ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --force-yes upgrade \
      | tee -a $logfile
  fi

  apt-get -qq remove nodejs* --force-yes > /dev/null 2>&1
  apt-get -qq remove npm* --force-yes > /dev/null 2>&1
  
  if [[ $version =~ '12.04' ]]; then
    log "Adding custom Debian repositories for Ubuntu 12.04..."
    apt-get -qq install python-software-properties --force-yes

    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - > /dev/null 2>&1
    echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list 2>&1
    add-apt-repository ppa:nginx/stable -y > /dev/null 2>&1
    add-apt-repository ppa:git-core/ppa -y > /dev/null 2>&1
    apt-get -qq update | tee -a $logfile
  fi
  
  log "Installing Debian Packages (this will take a few minutes)..."

  apt-get -qq install \
    curl build-essential libssl-dev openssh-server cups git-core nginx-full apache2-utils vim \
    postgresql-$XT_PG_VERSION postgresql-server-dev-$XT_PG_VERSION \
    postgresql-contrib-$XT_PG_VERSION postgresql-$XT_PG_VERSION-plv8 \
    libavahi-compat-libdnssd-dev \
    perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python \
    couchdb --force-yes | tee -a $logfile > /dev/null 2>&1

  log "Cleaning up packages..."
  apt-get -qq autoremove --force-yes > /dev/null 2>&1
}

install_node () {
  log "Installing node.js..."
  wget git.io/FsmDSw -qO n.bash
  chmod +x n.bash
  mv n.bash /usr/bin/n
  n 0.8.26
  n latest
  n stable
  mkdir -p /usr/local/{share/man,bin,lib/node,lib/node_modules,include/node}
  chmod -R a+w /usr/local/{share/man,bin,lib/node*,include/node*,n,ChangeLog,LICENSE,README.md}
}

log() {
  echo -e "[xtuple] $@"
  echo -e "[xtuple] $@" >> $logfile
}
die() {
  TRAPMSG="$@"
  log $@
  exit 1
}

trap 'CODE=$? ; log "\n\nxTuple bootstrap Aborted:\n  line: $BASH_LINENO \n  cmd: $BASH_COMMAND \n  code: $CODE\n  msg: $TRAPMSG\n" ; exit 1' ERR

if [[ -z $XT_PG_VERSION ]]; then
  export XT_PG_VERSION="9.3"
fi

log "This program will install and configure the system dependencies for xTuple."
log ""
log "         xxx     xxx"
log "          xxx   xxx "
log "           xxx xxx  "
log "            xxxxx   "
log "           xxx xxx  "
log "          xxx   xxx "
log "         xxx     xxx\n"

if [[ ! -z $(which apt-get) ]]; then
  install_debian
  install_node
  echo ''
else
  log "apt-get not found."
  exit 1;
fi

log "Done! You now have yourself a bona fide xTuple Server."
log "We recommend that you reboot the machine now"
rm -f bootstrap.sh
