#!/bin/bash
set -x -u

# Pre-installed lite version apk should have a reference to mwm and ttf assets in the gradle file

# Yota 1st generation

SRC=../../../data
DST=../../android/YoPme/assets

./update_assets_for_version.sh $SRC $DST
./add_assets_mwm-ttf.sh $DST


rm -rf $DST/drules_proto.bin
rm -rf $DST/drules_proto_dark.bin
rm -rf $DST/drules_proto_clear.bin
ln -s $SRC/drules_proto-bw.bin $DST/drules_proto.bin

rm -rf $DST/resources-ldpi
rm -rf $DST/resources-mdpi
rm -rf $DST/resources-hdpi
rm -rf $DST/resources-xhdpi
rm -rf $DST/resources-xxhdpi
rm -rf $DST/resources-ldpi_dark
rm -rf $DST/resources-mdpi_dark
rm -rf $DST/resources-hdpi_dark
rm -rf $DST/resources-xhdpi_dark
rm -rf $DST/resources-xxhdpi_dark
rm -rf $DST/resources-ldpi_clear
rm -rf $DST/resources-mdpi_clear
rm -rf $DST/resources-hdpi_clear
rm -rf $DST/resources-xhdpi_clear
rm -rf $DST/resources-xxhdpi_clear
ln -s $SRC/resources-yota $DST/resources-mdpi

# Yota 2nd generation

DST=../../android/YoPme2/assets

./update_assets_for_version.sh $SRC $DST
./add_assets_mwm-ttf.sh $DST


rm -rf $DST/drules_proto.bin
rm -rf $DST/drules_proto_dark.bin
rm -rf $DST/drules_proto_clear.bin
ln -s $SRC/drules_proto-bw.bin $DST/drules_proto.bin

rm -rf $DST/resources-ldpi
rm -rf $DST/resources-mdpi
rm -rf $DST/resources-hdpi
rm -rf $DST/resources-xhdpi
rm -rf $DST/resources-xxhdpi
rm -rf $DST/resources-ldpi_dark
rm -rf $DST/resources-mdpi_dark
rm -rf $DST/resources-hdpi_dark
rm -rf $DST/resources-xhdpi_dark
rm -rf $DST/resources-xxhdpi_dark
rm -rf $DST/resources-ldpi_clear
rm -rf $DST/resources-mdpi_clear
rm -rf $DST/resources-hdpi_clear
rm -rf $DST/resources-xhdpi_clear
rm -rf $DST/resources-xxhdpi_clear
ln -s $SRC/resources-yota $DST/resources-mdpi
