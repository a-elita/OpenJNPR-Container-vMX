#!/bin/bash
# Copyright (c) 2017, Juniper Networks, Inc.
# All rights reserved.

#-----------------------------------------------------------
function extract_licenses {
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [ ! -z "$line" ]; then
      tmp="$(echo "$line" | cut -d' ' -f1)"
      if [ ! -z "$tmp" ]; then
        file=config_drive/config/license/${tmp}.lic
        >&2 echo "  writing license file $file ..."
        echo "$line" > $file
      else
        echo "$line" >> $file
      fi
    fi
  done < "$1"
}

#==================================================================
METADISK=$1
CONFIG=$2
LICENSE=$3

echo "METADISK=$METADISK CONFIG=$CONFIG LICENSE=$LICENSE"

echo "Creating config drive (configdrive.img) ..."
mkdir config_drive
mkdir config_drive/boot
mkdir config_drive/var
mkdir config_drive/var/db
mkdir config_drive/var/db/vmm
mkdir config_drive/var/db/vmm/etc
mkdir config_drive/config
mkdir config_drive/config/license
cat > config_drive/boot/loader.conf <<EOF
vmchtype="vmx"
vm_retype="RE-VMX"
vm_instance="0"
EOF
if [ -f "$LICENSE" ]; then
  echo "extracting licenses from $LICENSE"
  $(extract_licenses $LICENSE)
fi

junospkg=$(ls /u/junos-*-x86-*tgz 2>/dev/null)
if [ ! -z "$junospkg" ]; then
  echo "adding $junospkg"
  filebase=$(basename $junospkg)
  cp $junospkg config_drive/var/db/vmm/
  PKG=$(echo $filebase|cut -d'-' -f1,2)
  if [ ! -z "$PKG" ]; then
    cat >> config_drive/var/db/vmm/etc/rc.vmm <<EOF
installed=\$(pkg info | grep $PKG)
if [ -z "\$installed" ]; then
  echo "Adding package $PKG (file $junospkg)"
  pkg add /var/db/vmm/$filebase
  reboot
fi
EOF
  fi
fi

echo "adding config file $CONFIG"
cp $CONFIG config_drive/config/juniper.conf

cd config_drive
tar zcf vmm-config.tgz *
rm -rf boot config var
cd ..

# Create our own metadrive image, so we can use a junos config file
# 50MB should be enough.
dd if=/dev/zero of=metadata.img  bs=1M count=50 >/dev/null 2>&1
mkfs.vfat metadata.img >/dev/null 
mount -o loop metadata.img /mnt
cp config_drive/vmm-config.tgz /mnt
umount /mnt
qemu-img convert -O qcow2 metadata.img $METADISK
rm metadata.img
ls -l $METADISK

