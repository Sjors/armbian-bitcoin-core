Use [Armbian](https://www.armbian.com) to (automagically) compile Linux for your
device, compile Bitcoin Core, copy the blockchain and create an image for your SD card.

## Ingredients

* a board supported by Armbian. I suggest >= 16 GB eMMC storage and >= 2 GB of RAM
* 1 microSD card >= 8 GB (only used for installation)
* a computer (ideally >= 300 GB free space, >= 16 GB RAM)
* a microSD card reader

## Download and prune blockchain

Download and install Bitcoin Core on your computer and wait for the full blockchain
to sync. A few hints, if you open the Preferences (`Command` + `,` on macOS):

* set "Size of database cache" to 1 GB less than your RAM (though no more than 10 GB). This makes things a lot faster.
* click Open Configuration File and enter `prune=1`
* if you have less than 200 GB of free disk space, use`prune=...` instead, with the amount in megabytes.  Make it as large as possible, no less than 30000, but leave at least 50 GB free space. Unfortunately this does slow things down a bit. When you're done, you can reduce it all the way to 2 GB.
* if you have an existing installation, make a copy of your bitcoin data directory (see below). Delete your wallet from the copy. If you don't have space for a fully copy, you can also put this copy on a USB drive.

When it's done, quit bitcoind and change `prune=1` to `prune=550`. Start Bitcoin
Core again, wait a minute and quit. This deleted all but the most recent blocks.

## Put the blockchain in a shared folder

Create a `shared` folder somewhere on your computer. Create a directory `bitcoin`
inside of it, copy the `blocks` and `chainstate` folders to it. For testnet, create
`bitcoin/testnet3` and copy `testnet3/blocks` and `testnet3/chainstate`.

## Virtual Box

Download [Virtual Box](https://www.virtualbox.org/wiki/Downloads), install it and
when it asks, also install the guest extensions. The latter lets you share a folder
between your computer and the VM.

Armbian is picky about which Ubuntu version you use, so we'll use Ubuntu 18.04 Bionic
both for the virtual machine as well as the device. If that doesn't work for some reason,
the instructions below and all scripts most likely also work for Ubuntu 16.04 Xenial.

If you already use Ubuntu 18.04 then of course you won't need the virtual machine,
though if you run into strange errors, it might be worth trying.

Download the [Ubuntu Server installer](https://www.ubuntu.com/download/server).

Here's a good [step by step guide](https://github.com/bitcoin-core/docs/blob/master/gitian-building/gitian-building-create-vm-debian.md)
for installing the VM, which some changes:

* where it says "Debian", select "Ubuntu"
* whenever you need a machine / user / disk name, enter "armbian"
* give it as many CPU's as you have, but limit them to 90% so your machine doesn't freeze
* give it at least 4 GB RAM, or 2 GB for every CPU you have, whichever is more
* disk size: 50 GB should do
* you can skip the Network Tab section, but
  * you should become familiar with SSH anyhow
  * Ubuntu doesn't enable SSH by default, so type `sudo apt-get install shh` after installation
* the Ubuntu installer is pretty similar to the Debian one shown on that page (when in doubt, press enter) 
  * it skips the root user stuff, so you just need to create a single password

Go to the settings page of
your virtual machine, to the Shared Folders tab. Click the + button, find the
folder you just created, enter `shared` as the name and check the auto mount box.

Once the installation is complete, it should reboot the VM and you should see a
login prompt. Use the password you entered earlier.

## Prepare and start Armbian build

Click on the VM window and then select Insert Guest Editions CD from the Devices menu.

The `prepare-build.sh` script in this repository takes care of cross-compiling
Bitcoin Core (if you're not using desktop) and starting the Armbian build process.

If needed, it will install the Guest Editions and ask you to reboot: `sudo reboot`.

```sh
$ mkdir src
$ git clone https://github.com/Sjors/armbian-bitcoin-core.git
$ ./armbian-bitcoin-core/prepare-build.sh -h
Usage: ./armbian-bitcoin-core/prepare-build.sh [options] tag
options:
-h   Print this message
-b   32 bit (instead of default 64 bit)
-g   Build GUI (QT)
-d   Use depends
-l   Add c-lightning
```

To build Bitcoin Core 0.16 without GUI, for a 32 bit device, with lightning:

```sh
./armbian-bitcoin-core/previous_release.sh -b -l v0.16.1
```

After some initial work, it will ask you to select your board. Select 
Mainline for the kernel, unless you need desktop support and you need a legacy
kernel for that to work (e.g. for Orange Pi Plus 2E).

Sit back and wait... If all goes well, it should output something like:

```
[ o.k. ] Writing U-boot bootloader [ /dev/loop1 ]
[ o.k. ] Done building [ /home/armbian/build/output/images/Armbian_5.46_Nanopineoplus2_Ubuntu_bionic_next_4.14.48.img ]
[ o.k. ] Runtime [ 30 min ]
```

Move the resulting image to the shared folder so you can access it:

```sh
mv /home/armbian/build/output/images/Armbian*.img ~/shared
```

You can shut the VM down now.

## Prepare bootable microSD card

Use [Etcher](https://etcher.io) to put the resulting `.img` file on the SD card.

The first time you login your user is `bitcoin` and your password is `bitcoin` (you'll be ask to pick a new one).

If everything works, you can delete the VM if you like, but if you keep it around,
the second time will be faster.

This is a good time to enable wifi if your device supports it:

```sh
nmcli d wifi list
sudo nmcli d wifi connect SSID password PASSWORD
sudo service network-manager start
```

To connect to it via SSH, first, find the IP address (most likely under wlan, `inet 192.168.x.x`):

```sh
ifconfig
```

On your computer, edit `.ssh/config` and add:

```
Host pi-wifi
    HostName 192.168.x.x
    User pi
```

## Copy microSD card to device eMMC

The device has eMMC storage which is faster than the microSD card, and you may
want to be able to use the card.

To copy it over: 

```sh
sudo nand-sata-install
```

This powers off the device when its done. Eject the microSD card and start
the device.

The [emmc-boot service](/vendor/armbian/emmc-boot.sh) should now kick in and
start spinning up Bitcoin, Lightning and the web server. It may take a few minutes.

## Check

## Congrats

If you pulled this off successfully, you now have the right skills to help the
world verify that Bitcoin Core binaries are actually derived from the source code.
Consider [contributing a Gitian build](https://github.com/bitcoin-core/docs/blob/master/gitian-building.md).
