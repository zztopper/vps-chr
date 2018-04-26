#!/bin/bash
VER=`curl -s http://upgrade.mikrotik.com/routeros/LATEST.6 -H 'User-Agent: RouterOS 6.39.2'`
LATEST=`echo $VER|cut -d" " -f1`
TS=`echo $VER|cut -d" " -f2`
DAT=`date -r $TS`
echo "Latest version online is: $LATEST,
it was updated on: $DAT"
#Setting variables
PARTITION=`mount | grep 'on / type' | cut -d" " -f1`
DISK=${PARTITION::-1}
echo "Disk: $DISK"
INTERFACE=`ip link show | grep state | grep -v 'lo' | cut -d" " -f2 | cut -d":" -f1`
echo "Interface: $INTERFACE"
ADDRESS=`ip -4 addr show $INTERFACE | grep global | cut -d' ' -f 6 | head -n 1`
echo "IPv4 address: $ADDRESS"
GATEWAY=`ip -4 route list | grep default | cut -d' ' -f 3`
echo "IPv4 gateway: $GATEWAY"
ADDRESS6=`ip -6 addr show $INTERFACE | grep global | grep inet6 | cut -d' ' -f 6 | head -n 1`
echo "IPv6 address: $ADDRESS6"
GATEWAY6=`ip -6 route list | grep default | cut -d' ' -f 3`
echo "IPv6 gateway: $GATEWAY6"
PASSWORD='passw0rd'
echo "User: root Password: passw0rd"
echo "Check parameters, if wrong - press Ctrl+C"
sleep 10

#Installing Prerequisities
apt-get update&&apt-get install pv wget unzip kpartx qemu-utils -y

#Begin installing
wget https://download2.mikrotik.com/routeros/$LATEST/chr-$LATEST.img.zip -O chr.img.zip
gunzip -c chr.img.zip > chr.img
qemu-img convert chr.img -O qcow2 chr.qcow2
modprobe nbd
qemu-nbd -c /dev/nbd0 chr.qcow2
echo "Give some time for qemu-nbd to be ready"
sleep 10
partx -a /dev/nbd0
mount /dev/nbd0p2 /mnt
echo "/ip dhcp-client disable 0
/ip address add address=$ADDRESS interface=[/interface ethernet find where name=ether1]
/ip route add gateway=$GATEWAY
/ip service disable 0,1,2,4,5,7
/ip dns set servers=1.1.1.1
/system package enable [find where name=ipv6]
/system package disable [find where name=wireless]
/system package disable [find where name=ups]
/system package disable [find where name=hotspot]
/user set 0 name=root password=$PASSWORD
 " > /mnt/rw/autorun.scr
rm -rf /mnt/var/pdb/dude
rm -f /mnt/var/pdb/ipv6/disabled
sync
umount /mnt
sleep 1
echo "Compressing to gzip, this can take several minutes"
mount -t tmpfs tmpfs /mnt
pv /dev/nbd0 | gzip > /mnt/chr-extended.gz
sleep 1
killall qemu-nbd
sleep 1
echo u > /proc/sysrq-trigger
echo "Warming up sleep"
sleep 1
echo "Writing raw image, this will take time"
zcat /mnt/chr-extended.gz | pv | dd of=$DISK
echo "Sleep 5 seconds (if lucky)"
sleep 5 || true
echo "sync disk"
echo s > /proc/sysrq-trigger
echo "Ok, reboot"
echo b > /proc/sysrq-trigger