#!/bin/bash
CONFIG_FLAGS=" --disable-tests --disable-bench"
USE_DEPENDS=0
GUI=0
BIT32=0
LIGHTNING=
BITCOIN_DATADIR=shared/bitcoin

while getopts ":hgdb" opt; do
  case $opt in
    h)
      echo "Usage: ./armbian-bitcoin-core//prepare-build.sh -b 32 [options] tag"
      echo "  options:"
      echo "  -h   Print this message"
      echo "  -b   32 bit (instead of default 64 bit)"
      echo "  -g   Build GUI (QT)"
      # echo "  -j   Number of parallel threads to use during build" # TODO
      # echo "  -t   Use testnet" # TODO
      # echo "  -..." override bitcoin datadir
      echo "  -d   Use depends"
      echo "  -l   Add c-lightning"
      exit 0
      ;;
    b)
      BIT32=1
      ;;
    g)
      GUI=1
      ;;
    d)
      USE_DEPENDS=1
      ;;
    l)
      LIGHTNING=c
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

if [ -z "$1" ]; then
  echo "Specify release tag, e.g.: .previous_release v0.15.1"
  exit 1
fi

# TODO: sanity checks, like making sure blocks and chainstate dirs are present
# TODO: skip stuff if it's already done

echo "Enter your sudo password in order to install dependencies."

sudo apt-get install automake autotools-dev libtool g++-aarch64-linux-gnu \
             g++-arm-linux-gnueabihf pkg-config ccache curl

# Can't cross compile with GUI, so compilation happens in customize-image.sh
# https://github.com/bitcoin/bitcoin/issues/13495.
# if [ "$GUI" -eq "0" ]; then



if [ "$GUI" -eq "0" ]; then
  git clone https://github.com/bitcoin/bitcoin.git src/bitcoin
  pushd src/bitcoin
    git checkout $1
    pushd depends
      if [ "$BIT32" -eq "1" ]; then
        make HOST=arm-linux-gnueabihf NO_WALLET=1 NO_UPNP=1 NO_QT=1 -j5
      else
        make HOST=aarch64-linux-gnu NO_WALLET=1 NO_UPNP=1 NO_QT=1 -j5
      fi
    popd
    ./autogen.sh
    if [ "$BIT32" -eq "1" ]; then
      ./configure $CONFIG_FLAGS --prefix=$PWD/depends/arm-linux-gnueabihf --enable-glibc-back-compat --enable-reduce-exports LDFLAGS=-static-libstdc++
    else
      ./configure --disable-bench --disable-tests --prefix=$PWD/depends/aarch64-linux-gnu --enable-glibc-back-compat --enable-reduce-exports LDFLAGS=-static-libstdc++
    fi
    make -j5 # use -j flag
  popd
fi

# TODO: can't cross compile c-lightning yet
# if [ "$LIGHTNING" -eq "c" ]; then

# Armbian
git clone https://github.com/armbian/build.git

mkdir -p build/userpatches/overlay/bin
cp armbian-bitcoin-core/customize-image.sh build/userpatches
cp armbian-bitcoin-core/lib.config build/userpatches

# Copy bitcoind to the right place, if cross compiled:

if [ "$GUI" -eq "0" ]; then
  cp src/bitcoin/src/bitcoind src/bitcoin/src/bitcoin-cli build/userpatches/overlay/bin
fi

# Copy block index and chainstate:

mkdir build/userpatches/overlay/bitcoin
# mkdir ~/build/userpatches/overlay/bitcoin/testnet3
cp -r $BITCOIN_DATADIR/blocks ~/build/userpatches/overlay/bitcoin
# cp -r $BITCOIN_DATADIR/testnet3/blocks ~/build/userpatches/overlay/bitcoin/testnet3
cp -r $BITCOIN_DATADIR/chainstate ~/build/userpatches/overlay/bitcoin
# cp -r $BITCOIN_DATADIR/testnet3/chainstate ~/build/userpatches/overlay/bitcoin/testnet3

pushd build
  if [ "$GUI" -eq "0" ]; then
    ./compile.sh RELEASE=bionic BUILD_DESKTOP=no KERNEL_ONLY=no KERNEL_CONFIGURE=no PRIVATE_CCACHE=yes
  else
    ./compile.sh RELEASE=xenial BUILD_DESKTOP=yes KERNEL_ONLY=no KERNEL_CONFIGURE=no PRIVATE_CCACHE=yes
  fi
fi
