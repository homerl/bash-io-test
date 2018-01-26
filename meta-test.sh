#!/bin/bash
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
  time (touch 11111112222222333333333444444445555555555677777777777zzzzzzzzzkr2sfsdkfjlfk3j23ijksljfgksldf{0..65535} && touch 11111112222222333333333444444445555555555677777777777zzzzzzzzzkr2sfsdkfsdfjsidfsidfjsdfisdfjllsdfjiejlfk3j23ijksljfgksldf{65536..131070} && touch 11111112222222333333333444444445555555555677777777777zzzzzzzzzkr2sfsdkfsdfjsidfsidfjsdfisdfjllsdfjiejlfk3j23ijksljfgksldf{131071..196605} && touch 11111112222222333333333444444445555555555677777777777zzzzzzzzzkr2sfsdkfsdfjsidfsidfjsdfisdfjllsdfjiejlfk3j23ijksljfgksldf{196606..262140} ) > $resdir/touch_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (ls -l > /dev/zero) > $resdir/ls_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (ls | xargs stat) > $resdir/stat_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (setfacl -m u:nobody:rwx,g:nobody:rwx ./*) > $resdir/setacl_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (getfacl ./*) > $resdir/getacl_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (chown root.nobody ./*) > $resdir/chown_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (chmod g+s ./*) > $resdir/chmod_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (setfattr -n user.comment -v "this is a comment" ./*) > $resdir/setfattr_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (getfattr ./* -n user.comment) > $resdir/getfattr_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (chattr +i ./*) > $resdir/chattri_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (lsattr -v ./*) > $resdir/lsattr_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (mkdir test10;mv ./* test10) > $resdir/mv_${1} 2>&1
  echo 3 > /proc/sys/vm/drop_caches
  time (cd /mnt/$ipaddr/test100 && rm -rf ./test10) > $resdir/rm_${1} 2>&1
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

                metatest $i $testdir
                echo >&7
        } &
done
wait
exec 7>&-
