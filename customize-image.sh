#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

# TODO: exit with non-zero status if anything goes wrong

sudo -s <<'EOF'  
  # User with sudo rights and initial password:
  useradd bitcoin -m -s /bin/bash --groups sudo
  echo "bitcoin:bitcoin" | chpasswd
  echo "bitcoin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/bitcoin
EOF

# TODO copy ssh pubkey if found, disable password SSH login

# Install Bitcoin Core
if [ "$BUILD_DESKTOP" == "no" ]; then
  sudo cp /tmp/overlay/bin/bitcoin* /usr/local/bin
else
  sudo -s <<'EOF'
    git clone https://github.com/bitcoin/bitcoin.git /usr/local/src/bitcoin
    cd /usr/local/src/bitcoin
    git checkout v0.16.1
    # TODO: check signature commit hash

    sudo add-apt-repository ppa:bitcoin/bitcoin
    sudo apt-get update
    sudo apt-get install -y libdb4.8-dev libdb4.8++-dev
    # apt enters a confused state, perform incantation and try again:
    sudo apt-get -y -f install
    sudo apt-get install -y libdb4.8-dev libdb4.8++-dev

    cd /usr/local/src/bitcoin
    ./autogen.sh
    if ! ./configure --disable-tests --disable-bench --with-qrencode --with-gui=qt5 ; then
      exit 1
    fi
    make
    sudo make install
EOF
fi

# Configure Bitcoin Core:
sudo -s <<'EOF'
  mkdir /home/bitcoin/.bitcoin
  # TODO: get GB RAM from $BOARD or user input (menu?)
  echo "prune=2000" >> /home/bitcoin/.bitcoin/bitcoin.conf
  echo "peerbloomfilters=0" >> /home/bitcoin/.bitcoin/bitcoin.conf
  echo "maxuploadtarget=100" >> /home/bitcoin/.bitcoin/bitcoin.conf
  
  # TODO: offer choice between mainnet and testnet
  # echo "testnet=1" >> /home/bitcoin/.bitcoin/bitcoin.conf
  # mkdir /home/bitcoin/.bitcoin/testnet3

  # Copy block index and chain state from host:
  cp -r /tmp/overlay/bitcoin/chainstate /home/bitcoin/.bitcoin
  cp -r /tmp/overlay/bitcoin/blocks /home/bitcoin/.bitcoin
  
  # cp -r /tmp/overlay/bitcoin/testnet3/chainstate /home/bitcoin/.bitcoin/testnet3
  # cp -r /tmp/overlay/bitcoin/testnet3/blocks /home/bitcoin/.bitcoin/testnet3

  chown -R bitcoin:bitcoin /home/bitcoin/.bitcoin
EOF

sudo -s <<'EOF'  
  # Disable root login
  passwd -l root
  
  # Require password reset:
  passwd -e bitcoin
EOF
