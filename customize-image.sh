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
  # Disable root login
  passwd -l root

  # User with sudo rights and initial password:
  useradd bitcoin -m -s /bin/bash --groups sudo
  echo "bitcoin:bitcoin" | chpasswd
  passwd -e pi
  echo "bitcoin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/pi
EOF

# TODO copy ssh pubkey if found, disable password SSH login

# Install Bitcoin Core
if [ "$BUILD_DESKTOP" -eq "0" ]; then
  sudo cp /tmp/overlay/bin/bitcoin* /usr/local/bin
else
  sudo -s <<'EOF'
    git clone https://github.com/bitcoin/bitcoin.git /usr/local/src/bitcoin
    cd /usr/local/src/bitcoin
    git checkout v0.16.1
    # TODO: check signature commit hash
    # TODO: use depends system
    ./contrib/install_db4.sh `pwd`
    cd /usr/local/src/bitcoin
    ./autogen.sh
    export BDB_PREFIX='/usr/local/src/bitcoin/db4'
    ./configure BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include" --disable-tests --disable-bench --with-qrencode --with-gui=qt5  
    make -j5 # TODO: configureable
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
  echo "testnet=1" >> /home/bitcoin/.bitcoin/bitcoin.conf

  # Copy block index and chain state from host:
  # mkdir /home/bitcoin/.bitcoin/testnet3
  # cp -r /tmp/overlay/chainstate /home/bitcoin/.bitcoin
  # cp -r /tmp/overlay/testnet3/chainstate /home/bitcoin/.bitcoin/testnet3
  # cp -r /tmp/overlay/blocks /home/bitcoin/.bitcoin
  # cp -r /tmp/overlay/testnet3/blocks /home/bitcoin/.bitcoin/testnet3

  chown -R bitcoin:bitcoin /home/bitcoin/.bitcoin
EOF
