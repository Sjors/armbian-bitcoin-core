#!/bin/bash
git clone https://github.com/ElementsProject/lightning.git src/lightning
git checkout v0.6rc2
cd src/lightning
./configure
make
sudo make install
