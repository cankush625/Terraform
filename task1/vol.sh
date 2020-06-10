#!/bin/bash
sudo yum install httpd -y
sudo systemctl start httpd
sudo systemctl enable httpd
sudo yum install git -y

fdisk /dev/xvdc << FDISK_CMDS
g
n
1
 
+500MiB
n
2
 
 
t
1
83
t
2
83
w
FDISK_CMDS

mkfs -t ext4 /dev/xvdc1
mount /dev/xvdc1 /var/www/html
cd /var/www/html
git clone https://github.com/cankush625/Web.git
rm -r /assets