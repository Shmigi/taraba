#!/bin/bash

# This is for x64 Intel CPU with SSSE4 instructions
# To check your CPU type, run: cat /proc/cpuinfo   and look for "sse4_1" in the "flags" line then this script works
# To check x32 vs x64, run: getconf LONG_BIT
# If your CPU isnt an x64 or have sse4 support, then get your .so file version at: http://asterisk.hosting.lv/

# This is for internal use of "Bicom Systems Staff"

echo -------
echo This installs the open source version of the g729 codec
echo WARNING - This is only for x64 Intel CPU with SSSE4 instructions -
echo -------
read -rsp $'Press any key to continue  OR  CTRL-c to QUIT ...\n' -n1 key

cd

# Install g729 codec, fetch, rename and move to folder, change permissions.
wget http://asterisk.hosting.lv/bin/codec_g729-ast130-gcc4-glibc2.2-x86_64-core2-sse4.so
cp codec_g729-ast130-gcc4-glibc2.2-x86_64-core2-sse4.so /opt/pbxware/pw/usr/lib/asterisk/modules/codec_g729.so
chmod 755 /opt/pbxware/pw/usr/lib/asterisk/modules/codec_g729.so
chown 555:555 /opt/pbxware/pw/usr/lib/asterisk/modules/codec_g729.so

# load codec in Asterisk and pause 10 sec
echo Load codec to Asterisk
asterisk -rx 'module load codec_g729.so'
sleep 10
# show translation from Asterisk
echo Checking Asterisk transcoding please wait ....
sleep 10
asterisk -rx 'core show translation recalc 10'
echo -------
echo If you see g729 above then codec is installed succesfully. Otherwise check the Asterisk logs.
echo -------
