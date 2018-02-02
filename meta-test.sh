#!/bin/bash
###########################################################################
# Script:       $0
# Author:       Homer Li
# Modify:       Homer Li
# Date:         2018-1-26
# Update:       2018-1-26
# Email:        liyan2@genomics.org.cn
# Usage:        $0
# Discription:  test posix meta data performance
#
###########################################################################
ipaddr=$(ip a | awk --posix -F '[ /]+' 'BEGIN{i=0};$0~/[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}/ && $0~/inet/ && $0!~/inet6/ && $0!~/10.53.27/ && $0!~/10.53.28/ && $0!~/0.0.0.0/ && $0!~/127.0.0.1/ && $0!~/00:00/ {if(i==0) print $3;i++}')
resdir=/dev/shm/$ipaddr/mdtest
mkdir -p $resdir

usage() {
        echo "Usage: $0 [-d test dir] [-p process number] [-j runing jobs]" 2>&1; exit 1;
}

while getopts ":d:p:j:" o; do
    case "${o}" in
        d)
            export testdir=${OPTARG}"/"$ipaddr
            ;;
        p)
            export total=${OPTARG} #Number of running process in this pool
            ;;
        j)
            export Npro=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

[[ -z $testdir ]] && usage && exit 1

metatest() {
  workdir=$2"/test"$1
  mkdir -p $workdir; cd $workdir
  time (touch $3{0..65535} && touch $3{65536..131070} && touch $3{131071..196605} && touch $3{196606..262140} ) > $resdir/touch_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (mkdir $3{0..65535} && mkdir $3{65536..131070} && mkdir $3{131071..196605} && mkdir $3{196606..262140} ) > $resdir/mkdir_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  #time (ls -l > /dev/zero) > $resdir/ls_${1} 2>&1
  time (ls -l > /dev/zero) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (ls | xargs stat) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (setfacl -m u:nobody:rwx,g:nobody:rwx ./*) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (getfacl ./*) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (chown root.nobody ./*) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (chmod g+s ./*) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (setfattr -n user.comment -v "this is a comment" ./*) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (getfattr ./* -n user.comment) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (chattr +ai ./*) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (chattr -ai ./*) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (lsattr -v ./*) > /dev/zero 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (mkdir test10;mv ./* test10) > /dev/zero 2>&1
  #echo 3 > /proc/sys/vm/drop_caches
  #time (cd /mnt/$ipaddr/test100 && rm -rf ./test10) > /dev/zero 2>&1
}
[[ -z $Npro ]] && export Npro=20
[[ -z $total ]] && export total=100

Pfifo="/tmp/$$.fifo"
mkfifo $Pfifo
exec 7<>$Pfifo
rm -f $Pfifo
for((i=1; i<=$Npro; i++)); do
        echo
done >&7
for ((i=1;i<=$total;i++))
do
        read -u7
        {

                [[ $(getconf ARG_MAX) -gt 2097152 ]] && filehead="11111112222222333333333444444445555555555677777777777zzzzzzzzzkriiiiiiiiiiiiiiiiiiiiiiiiiiiii"
                [[ $(getconf ARG_MAX) -le 2097152 ]] && filehead="hahahahahahahahahaha"
                metatest $i $testdir $filehead
                echo >&7
        } &
done
wait
exec 7>&-
