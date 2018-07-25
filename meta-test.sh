#!/bin/bash
###########################################################################
# Script:       $0
# Author:       Homer Li
# Modify:       Homer Li
# Date:         2018-1-26
# Update:       2018-7-25
# Email:        liyan2@genomics.org.cn
# Usage:        $0
# Discription:  test posix meta data performance
#
###########################################################################
ipaddr=$(ip a | awk --posix -F '[ /]+' 'BEGIN{i=0};$0~/[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}/ && $0~/inet/ && $0!~/inet6/ && $0!~/10.53.27/ && $0!~/10.53.28/ && $0!~/0.0.0.0/ && $0!~/127.0.0.1/ && $0!~/00:00/ {if(i==0) print $3;i++}')
resdir=/dev/shm/$ipaddr/mdtest
[[ ! -d $resdir ]] && mkdir -p $resdir
usage() {
        echo "Usage: $0 [-d test dir] [-p total jobs] [-j online jobs] [-n 0  0 means rm all files, 1 means no rm]" 2>&1; exit 1;
}
sysctl -w fs.file-max=500000
while getopts ":d:p:j:n:r" o; do
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
            export ifrm=${OPTARG}
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
  cd $workdir || exit 1
  time (j=0;for ((i=0;i<=60000;i=i+30000));  do j=$((j==0?0:((j+1))));[[ $i -gt 0 ]] && echo "touch $(openssl rand -hex 4)_{"$j".."$i"}";j=$i; done | bash  > /dev/zero) && echo "---touch finish---"
  time (echo $(openssl rand -hex 133) | tee -a $workdir/* >/dev/zeor) && echo "---append finish---"
  time (cat $workdir/* >/dev/zero) && echo "---read finish---"
  time (sed -i '/Z/ s//N/g' $workdir/*) && echo "---replace finish---"
  time (ls | xargs stat > /dev/zero)  && echo "---ls stat finish---"
  time (setfacl -b $workdir/* > /dev/zero) && echo "---setfacl 1 finish---"
  time (setfacl -m u:nobody:rwx,g:nobody:rwx $workdir/* > /dev/zero) && echo "---setfacl 2 finish---"
  time (getfacl $workdir/* > /dev/zero) && echo "---getfacl finish---"
  time (chown root.nobody $workdir/* > /dev/zero) && echo "---chown finish---"
  time (chmod g+s $workdir/* > /dev/zero) && echo "---chmod finish---"
  time (which setfattr && setfattr -n user.comment -v "this is a long comment $(openssl rand -hex 64)" $workdir/* > /dev/zero) && echo "---setfattr 1 finish---"
  time (setfattr -n user.checksum -v "md5 checksum $(openssl rand -hex 64)" $workdir/* > /dev/zero) && echo "---setfattr 2 finish---"
  time (which getfattr && getfattr $workdir/* -n user.comment > /dev/zero) && echo "---getfattr 1 finish---"
  time (setfattr -x user.checksum $workdir/* > /dev/zero) && echo "---setfattr 3 finish---"
  time (which chattr && chattr +ai $workdir/* > /dev/zero) && echo "---chattr 1 finish---"
  time (chattr -ai $workdir/* > /dev/zero) && echo "---chattr 2 finish---"
  time (du -hs $workdir/* > /dev/zero) && echo "---du finish---"
  time ([[ -n $workdir ]] && cd $workdir && [[ ! -d dir ]] && mkdir dir; cd dir && for i in {0..30}; do mkdir -p $(echo $(openssl rand -hex 4)_{0..200} | tr " " "/"); done > /dev/zero) && echo "---mkdir finish---"
  time (which prename && prename 's/$/.zip/' $workdir/* && prename 's/.zip$//' $workdir/* > /dev/zero) && echo "---rename finish---"
  time (du -hs $workdir > /dev/zero) && echo "---du step finish---"$?
   randv=$(openssl rand -hex 8)
  time (mkdir ${testdir}"/"${randv} && mv -f ./* ${testdir}"/"${randv}) && echo "---mv finish---"
  #echo Prepare to rmove ${testdir}${randv}
  #echo --------------output ifrm value:$ifrm
  #time ([[ $ifrm -eq 0 ]] && [[ -n ${testdir}"/"${randv} ]] && rm -rf ${testdir}"/"${randv} ) && echo "---rm finish---"$?
}
[[ -z $Npro ]] && export Npro=8
[[ -z $total ]] && export total=500
[[ -z $ifrm ]] && export ifrm=1

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
