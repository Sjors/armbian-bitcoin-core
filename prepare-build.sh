#!/bin/bash
CONFIG_FLAGS=" --disable-tests --disable-bench --enable-glibc-back-compat --enable-reduce-exports LDFLAGS=-static-libstdc++"
USE_DEPENDS=0
GUI=0
BIT32=0
LIGHTNING=
BITCOIN_DATADIR=shared/bitcoin
PREBUILT_BITCOIN_CORE=0
PARALLEL=1

while getopts ":hgdbpj:" opt; do
  case $opt in
    h)
      echo "Usage: ./armbian-bitcoin-core/prepare-build.sh -b 32 [options] tag"
      echo "  options:"
      echo "  -h   Print this message"
      echo "  -b   32 bit (instead of default 64 bit)"
      echo "  -g   Build GUI (QT)"
      echo "  -j   Number of parallel threads to use during build (each needs ~1.5 GB RAM)"
      # echo "  -t   Use testnet" # TODO
      # echo "  -..." override bitcoin datadir
      echo "  -d   Use depends"
      echo "  -l   Add c-lightning"
      echo "  -p   Use pre-built bitcoin core binaries in src/bitcoin"
      echo "  -c   Clean"
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
    p)
      PREBUILT_BITCOIN_CORE=1
      ;;
    j)
      PARALLEL=$OPTARG
      ;;
    c)
      if [ ! -d src/bitcoin ]; then
      echo "Clean bitcoin dir..."
        pushd src/bitcoin
          make distclean
          pushd depends
            # v0.17 will have "make clean-all"
            rm -rf built sources work x86_64* i686* mips* arm* aarch64*
          popd
        popd
      fi
      exit 0  
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

if [ "$PREBUILT_BITCOIN_CORE" -eq "0" ]; then
  if [ -z "$1" ]; then
    echo "Specify release tag, e.g.: .previous_release v0.15.1"
    exit 1
  fi
fi

# TODO: skip stuff if it's already done

echo "If asked, tnter your sudo password in order to upgrade your system, install dependencies and mount shared folder..."
sudo apt-get update
sudo apt-get dist-upgrade

echo "Installing dependencies..."
sudo apt-get install -y automake autotools-dev libtool g++-aarch64-linux-gnu \
             g++-arm-linux-gnueabihf pkg-config ccache curl build-essential \
             linux-headers-`uname -r` jq

echo "Check if guest editions are installed..."
if ! lsmod | grep vboxguest ; then
  read -p "Insert Guest Editions CD and press enter"
  if [ ! -d /media/cdrom ]; then
    sudo mkdir --p /media/cdrom
    sudo mount -t auto /dev/cdrom /media/cdrom/
    cd /media/cdrom/
    sudo sh VBoxLinuxAdditions.run
    sudo /media/cdrom/./VBoxLinuxAdditions.run
  fi

  echo "Installed guest editions. Please reboot and run this script again."
  exit 0
fi

echo "Mount shared drive if needed..."
if ! df -h | grep /shared ; then
  export USER_ID=`id -u`
  export GROUP_ID=`id -g`
  mkdir -p ~/shared
  sudo mount -t vboxsf -o umask=0022,gid=$GROUP_ID,uid=$USER_ID shared ~/shared
fi

# TODO: check ~/shared/bitcoin/blocks and ~/shared/bitcoin/chainstate exist

# Can't cross compile with GUI, so compilation happens in customize-image.sh
# https://github.com/bitcoin/bitcoin/issues/13495.
# if [ "$GUI" -eq "0" ]; then

if [ "$PREBUILT_BITCOIN_CORE" -eq "0" ]; then
  if [ "$GUI" -eq "0" ]; then
    if [ ! -d src/bitcoin ]; then
      git clone https://github.com/bitcoin/bitcoin.git src/bitcoin
    fi
    pushd src/bitcoin
      git reset --hard
      git checkout $1
      pushd depends
        if [ "$BIT32" -eq "1" ]; then
          make HOST=arm-linux-gnueabihf NO_QT=1 -j$PARALLEL
        else
          make HOST=aarch64-linux-gnu NO_QT=1 -j$PARALLEL
        fi
      popd
      ./autogen.sh
      if [ "$BIT32" -eq "1" ]; then
        ./configure $CONFIG_FLAGS --prefix=$PWD/depends/arm-linux-gnueabihf
      else
        ./configure $CONFIG_FLAGS --prefix=$PWD/depends/aarch64-linux-gnu
      fi
      make -j$PARALLEL
    popd
  fi
fi

echo "Check if bitcoin binaries are present..."
if [ "$GUI" -eq "0" ]; then
  FILES="bitcoin-cli bitcoind"
fi

for f in $FILES;
do
  if [ ! -f src/bitcoin/src/$f ]; then
    echo "Could not find $f in src/bitcoin/src"
    exit 1
  fi
done

# TODO: can't cross compile c-lightning yet
# if [ "$LIGHTNING" -eq "c" ]; then

if [ ! -d build ]; then
  echo "Cloning Armbian and adding patches..."
  git clone https://github.com/armbian/build.git
  mkdir -p build/userpatches/overlay/bin
  cp armbian-bitcoin-core/build-c-lightning.sh build/userpatches
  cp armbian-bitcoin-core/lib.config build/userpatches
fi

cp armbian-bitcoin-core/customize-image.sh build/userpatches

if [ "$LIGHTNING" == "c" ]; then
  echo "\nPACKAGE_LIST_ADDITIONAL=\"$PACKAGE_LIST_ADDITIONAL autoconf libtool libgmp-dev libsqlite3-dev python python3 net-tools zlib1g-dev\"" >> build/userpatches/lib.config
  
  echo "./compile-c-lightning.sh" >> build/userpatches/customize-image.sh
fi

# Copy bitcoind to the right place, if cross compiled:

if [ "$GUI" -eq "0" ]; then
  cp src/bitcoin/src/bitcoind src/bitcoin/src/bitcoin-cli build/userpatches/overlay/bin
fi

rm -rf build/userpatches/overlay/bitcoin
# Copy block index and chainstate:
mkdir -p build/userpatches/overlay/bitcoin
# mkdir build/userpatches/overlay/bitcoin/testnet3
cp -r $BITCOIN_DATADIR/blocks build/userpatches/overlay/bitcoin
# cp -r $BITCOIN_DATADIR/testnet3/blocks build/userpatches/overlay/bitcoin/testnet3
cp -r $BITCOIN_DATADIR/chainstate build/userpatches/overlay/bitcoin
# cp -r $BITCOIN_DATADIR/testnet3/chainstate build/userpatches/overlay/bitcoin/testnet3

pushd build
  if [ "$GUI" -eq "0" ]; then
    ./compile.sh RELEASE=bionic BUILD_DESKTOP=no KERNEL_ONLY=no KERNEL_CONFIGURE=no PRIVATE_CCACHE=yes
  else
    ./compile.sh RELEASE=xenial BUILD_DESKTOP=yes KERNEL_ONLY=no KERNEL_CONFIGURE=no PRIVATE_CCACHE=yes
  fi
popd
