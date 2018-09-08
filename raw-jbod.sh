#!/bin/bash
timeout=400
tmplog="tmp_logs"

[[ ! -d tmp_logs ]] && mkdir tmp_logs

for rwtype in {rw,read,write,rw,randread,randwrite,randrw}
do
#  for numjobs in {1,4,8}
  for numjobs in 1
  do
cat > fio.cfg << EOF
[global]
rw=$rwtype
ioengine=libaio
norandommap=1
iodepth=64
filesize=800G
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
          lsscsi -t | awk '$0~/sas/ && $0~/disk/ {print $NF}' | while read line;
          do
             echo [job-$line] >> fio.cfg
             echo filename=$line >> fio.cfg
          done
          echo 3 > /proc/sys/vm/drop_caches
          fio fio.cfg | tee $tmplog/fio-${rwtype}_${numjobs}_${bssize} 2>&1
  done
done
