#!/bin/bash
###########################################################################
# Script:       $0
# Author:       Homer Li
# Modify:       Homer Li
# Date:         2018-1-26
# Update:       2018-4-20
# Email:        liyan2@genomics.org.cn
# Usage:        $0
# Discription:  test posix meta data performance
#
###########################################################################
ipaddr=$(ip a | awk --posix -F '[ /]+' 'BEGIN{i=0};$0~/[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}/ && $0~/inet/ && $0!~/inet6/ && $0!~/10.53.27/ && $0!~/10.53.28/ && $0!~/0.0.0.0/ && $0!~/127.0.0.1/ && $0!~/00:00/ {if(i==0) print $3;i++}')
resdir=/dev/shm/$ipaddr/mdtest
[[ ! -d $resdir ]] && mkdir -p $resdir
usage() {
        echo "Usage: $0 [-d test dir] [-p process number] [-j runing jobs] [-n 0  0 means rm all files, 1 means no rm]" 2>&1; exit 1;
}
sysctl -w fs.file-max=100000000
while getopts ":d:p:j:n" o; do
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
        n)
            export nrm=${OPTARG}
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
  cd $workdir
  #(touch $3{0..65535} && touch $3{65536..131070} && touch $3{131071..196605} && touch $3{196606..262140} )
  j=0;for ((i=0;i<=2000000;i=i+1000000));  do j=$((j==0?0:((j+1))));[[ $i -gt 0 ]] && echo "touch $(openssl rand -hex 4)_{"$j".."$i"}";j=$i; done | bash  > /dev/zero
  echo "---touch return---"$?
  ### for test #(touch $3{0..15}) > /dev/zero
  ([[ ! -d dir ]] && mkdir dir; cd dir && for i in {0..300}; do mkdir -p $(echo $(openssl rand -hex 4)_{0..200} | tr " " "/"); done) > /dev/zero > /dev/zero
  echo "---mkdir return---"$?
  ### for test#([[ ! -d dir ]] && mkdir dir; cd dir && for i in {0..3}; do mkdir -p $(echo ${randv}_{0..5} | tr " " "/"); done) > /dev/zero > /dev/zero
  cd $workdir
  time (ls | xargs stat) > /dev/zero
  echo "---ls stat return---"$?
  time (setfacl -b $workdir/*) > /dev/zero
  echo "---setfacl 1 return---"$?
  time (setfacl -m u:nobody:rwx,g:nobody:rwx $workdir/*) > /dev/zero
  echo "---setfacl 2 return---"$?
  time (getfacl $workdir/*) > /dev/zero
  echo "---getfacl return---"$?
  time (chown root.nobody $workdir/*) > /dev/zero
  echo "---chown return---"$?
  time (chmod g+s $workdir/*) > /dev/zero
  echo "---chmod return---"$?
  time (setfattr -n user.comment -v "this is a long comment $(openssl rand -hex 64)" $workdir/*) > /dev/zero
  echo "---setfattr 1 return---"$?
  time (setfattr -n user.checksum -v "md5 checksum $(openssl rand -hex 64)" $workdir/*) > /dev/zero
  echo "---setfattr 2 return---"$?
  time (getfattr $workdir/* -n user.comment) > /dev/zero
  echo "---getfattr 1 return---"$?
  time (setfattr -x user.checksum $workdir/*) > /dev/zero
  echo "---setfattr 3 return---"$?
  time (chattr +ai $workdir/*) > /dev/zero
  echo "---chattr 1 return---"$?
  time (chattr -ai $workdir/*) > /dev/zero
  echo "---chattr 2 return---"$?
  time (echo $(openssl rand -hex 133) | tee -a $workdir/*) > /dev/zero
  echo "---append return---"$?
  time (cat $workdir/* ) > /dev/zero
  echo "---read return---"$?
  time (cat $workdir/* ) > /dev/zero
  value=$RANDOM > /dev/zero
  time (mkdir test${value};mv ./* test${value}) > /dev/zero
  echo "---mv return---"$?
  time (du -hs test${value}) > /dev/shm/meta_test_du_complete > /dev/zero
  echo "---du return---"$?
  time ([[ $nrm -eq 0 ]] && [[ -n $testdir ]] && cd $testdir && rm -rf ./test${value}) > /dev/zero
  echo "---rm return---"$?
}
[[ -z $Npro ]] && export Npro=8
[[ -z $total ]] && export total=16
[[ -z $nrm ]] && export nrm=0

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
