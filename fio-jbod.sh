#!/bin/bash
###########################################################################
# Script:       $0
# Author:       Homer Li
# Modify:       Homer Li
# Date:         2017-10-29
# Update:       2018-11-19
# Usage:        $0
# Discription:  Test raw dev from JBOD
# Written by:   Homer Li

#######################################################################
export fver=$1
if [[ ${#fver} -le 2 ]]
then
        echo "Not input firmware version, search the version"
        export fver=$(lsscsi | awk '{a[$(NF-1)]++;PROCINFO["sorted_in"] = "@val_num_desc"} END{for (i in a) {print i; break}}')
fi

echo "env check..."
if lsmod | grep zfs
then
        if zpool list | grep "no pools available"
        then
                rcode=0
        else
                echo found zfs mont point;
                rcode=1 && exit
        fi
elif df -T | grep -i lustre
then
        echo found lustre mount point, exit
        rcode=1 && exit
else
        rcode=0
fi

if [[ $rcode -eq 0 ]]
then
        ccolor=9
        echo -e "\e[38;5;${ccolor}m CAUTION !!! all data will be destroy, please make sure there is no any production data in local test env \e[0m "
        read -r -p "Are you sure? [y/N]; " response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
        then

                timeout=3600
                tmplog="tmp_logs"
                [[ ! -d tmp_logs ]] && mkdir tmp_logs

                for rwtype in {read,write,rw}
                do
                for numjobs in {1,8}
                do
cat > fio.cfg << EOF
[global]
rw=$rwtype
ioengine=libaio
norandommap=1
iodepth=4
filesize=1000G
numjobs=$numjobs
group_reporting
refill_buffers
exitall
time_based
runtime=$timeout
direct=1
EOF
                echo $rwtype | grep rand && echo bssplit=4K/100 >> fio.cfg && export bssize=4K
                echo $rwtype | grep -v rand && echo bssplit=1M/100 >> fio.cfg && export bssize=1M
                          lsscsi | awk -v fver=$fver '$0~/'"$fver"'/ {print $NF}' | while read line;
                          do
                                echo [job-$line] >> fio.cfg
                                echo filename=$line >> fio.cfg
                          done
                         echo 3 > /proc/sys/vm/drop_caches
                         fio fio.cfg | tee $tmplog/fio-${rwtype}_${numjobs}_${bssize} 2>&1
                  done
                done
        else
           echo "exit the script"
        fi
fi
