#!/bin/bash

echo "Mount shared drive if needed..."
if ! df -h | grep /shared ; then
  export USER_ID=`id -u`
  export GROUP_ID=`id -g`
  sudo mount -t vboxsf -o umask=0022,gid=$GROUP_ID,uid=$USER_ID shared ~/shared
fi

if ! which bitcoind ; then
  if [ ! -d src/bitcoin-local ]; then
    echo "Installing Bitcoin Core on this VM..."
    git clone https://github.com/bitcoin/bitcoin.git src/bitcoin-local
    pushd src/bitcoin-local
      git checkout v0.16.1
      # TODO: check git hash
      ./autogen.sh
      ./configure --disable-tests --disable-bench --disable-wallet --without-gui
      make
      echo "Sudo password required to finish install:"
      sudo make install
    popd
  else
    echo "Previous installation attempt failed?"
    exit 1
  fi
fi

bitcoind -daemon -prune=5000 -datadir=`pwd`/shared/bitcoin

echo "Waiting for chain to catch up..."
OPTS=-datadir=`pwd`/shared/bitcoin
set -o pipefail
while sleep 60
do
  if BLOCKHEIGHT=`bitcoin-cli $OPTS getblockchaininfo | jq '.blocks'`; then
    if bitcoin-cli $OPTS getblockchaininfo | jq -e '.initialblockdownload==false'; then
      echo "Almost caught up, wait 15 minutes..."
      sleep 900
      BLOCKHEIGHT=`bitcoin-cli $OPTS getblockchaininfo | jq '.blocks'`
      echo "Pruning to height $BLOCKHEIGHT..."
      bitcoin-cli $OPTS pruneblockchain $BLOCKHEIGHT
      bitcoin-cli $OPTS stop
      while sleep 10
      do # Wait for shutdown
        if [ ! -f ~/.bitcoin/bitcoind.pid ] && [ ! -f ~/.bitcoin/testnet3/bitcoind.pid ]; then
          break
        fi
      done
      break
    else
      echo "At block $BLOCKHEIGHT..."
    fi
  fi
done
