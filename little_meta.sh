#!/bin/bash
ulimit -s unlimited
echo 500000 > /proc/sys/fs/aio-max-nr
echo 500000 > /proc/sys/fs/file-max
ulimit -n 65535
n1=$(openssl rand -hex 16)
n2=$(openssl rand -hex 16)
mkdir ${n1}_100 ; cd ${n1}_100
echo ----touch---
time touch $(openssl rand -hex 8)_{0..59999}
echo 3 > /proc/sys/vm/drop_caches
echo ----tee -a-----
time echo $(openssl rand -hex 133)  | tee -a ./*
echo 3 > /proc/sys/vm/drop_caches
echo ----setfacl----
time setfacl -m u:nobody:rwx,g:nobody:rwx ./*
echo 3 > /proc/sys/vm/drop_caches
echo ----ls-----
time ls -l > /dev/zero
echo 3 > /proc/sys/vm/drop_caches
echo ----stat-----
time stat ./* > /dev/zero
echo 3 > /proc/sys/vm/drop_caches
echo ----setfattr-----
time setfattr -n user.checksum -v "md5 checksum $(openssl rand -hex 64)" ./*
echo 3 > /proc/sys/vm/drop_caches
echo ----rename-----
time (prename 's/$/.zip/' ./* && prename 's/.zip$//' ./* > /dev/zero)
echo 3 > /proc/sys/vm/drop_caches
#echo ----replace-----
#time (sed -i '/Z/ s//N/g' ./*)
#echo 3 > /proc/sys/vm/drop_caches
echo ----mkdir-----
time for i in {0..30}; do mkdir -p $(echo $(openssl rand -hex 4)_{0..200} | tr " " "/"); done
echo 3 > /proc/sys/vm/drop_caches
echo ----mv----
mkdir ../${n2}_200
cd ..
time mv ${n1}_100/* ${n2}_200
echo 3 > /proc/sys/vm/drop_caches
echo ----rm----
time rm -rf ${n2}_200 ${n1}_100
