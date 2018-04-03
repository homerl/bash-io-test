#!/bin/bash
###########################################################################
# Script:       $0
# Author:       Homer Li
# Modify:       Homer Li
# Date:         2018-1-26
# Update:       2018-4-03
# Email:        liyan2@genomics.org.cn
# Usage:        $0
# Discription:  test posix meta data performance
#
###########################################################################
ipaddr=$(ip a | awk --posix -F '[ /]+' 'BEGIN{i=0};$0~/[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}/ && $0~/inet/ && $0!~/inet6/ && $0!~/10.53.27/ && $0!~/10.53.28/ && $0!~/0.0.0.0/ && $0!~/127.0.0.1/ && $0!~/00:00/ {if(i==0) print $3;i++}')
resdir=/dev/shm/$ipaddr/mdtest
[[ ! -d $resdir ]] && mkdir -p $resdir
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

ulimit -s 1310720
[[ -z $testdir ]] && usage && exit 1

metatest() {
  workdir=$2"/test"$1
  [[ ! -d $workdir ]] && mkdir -p $workdir; cd $workdir
  set -e
  cd $workdir
  (touch $3{0..65535} && touch $3{65536..131070} && touch $3{131071..196605} && touch $3{196606..262140} )
  ### for test #(touch $3{0..15})
  randv=$(openssl rand -hex 4)
  ([[ ! -d dir ]] && mkdir dir; cd dir && for i in {0..300}; do mkdir -p $(echo ${randv}_{0..500} | tr " " "/"); done) > /dev/zero
  ### for test#([[ ! -d dir ]] && mkdir dir; cd dir && for i in {0..3}; do mkdir -p $(echo ${randv}_{0..5} | tr " " "/"); done) > /dev/zero
  cd $workdir
  time (ls -l > /dev/zero) > $resdir/ls_${1}
  (ls -lR)
  (ls | xargs stat)
  (setfacl -b $workdir/*)
  (setfacl -m u:nobody:rwx,g:nobody:rwx $workdir/*)
  (setfacl -m u:mail:rwx,g:nobody:rwx $workdir/*)
  (setfacl -m u:root:rwx,g:root:rwx $workdir/*)
  (setfacl -m u:bin:rwx,g:bin:rwx $workdir/*)
  (setfacl -m u:sshd:rwx,g:sshd:rwx $workdir/*)
  (setfacl -m u:ntp:rwx,g:ntp:rwx $workdir/*)
  (setfacl -m u:rpc:rwx,g:rpc:rwx $workdir/*)
  (setfacl -m u:nfsnobody:rwx,g:nfsnobody:rwx $workdir/*)
  (setfacl -m u:rpcuser:rwx,g:rpcuser:rwx $workdir/*)
  (setfacl -m u:adm:rwx,g:adm:rwx $workdir/*)
  (setfacl -m u:daemon:rwx,g:daemon:rwx $workdir/*)
  (setfacl -m u:ftp:rwx,g:ftp:rwx $workdir/*)
  (setfacl -m u:operator:rwx,g:root:rwx $workdir/*)
  (getfacl $workdir/*)
  (chown root.nobody $workdir/*)
  (chmod g+s $workdir/*)
  (setfattr -n user.comment -v "this is a long comment $(openssl rand -hex 64)" $workdir/*)
  (setfattr -n user.checksum -v "md5 checksum $(openssl rand -hex 64)" $workdir/*)
  (setfattr -n user.result_1000 -v "the others $(openssl rand -hex 64)" $workdir/*)
  (getfattr $workdir/* -n user.comment)
  (getfattr $workdir/* -n user.checksum)
  (getfattr $workdir/* -n user.result_1000)
  (setfattr -x user.result_1000 $workdir/*)
  (chattr +ai $workdir/*)
  (chattr -ai $workdir/*)
  (lsattr -v $workdir/*)
  value=$RANDOM
  (mkdir test${value};mv ./* test${value}) > /dev/zero 2>&1
  ([[ -n $testdir ]] && cd $testdir && rm -rf ./test${value}) > /dev/zero 2>&1
  set +e
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

                filehead=$(openssl rand -hex 32)
                metatest $i $testdir $filehead
                echo >&7
        } &
done
wait
exec 7>&-
