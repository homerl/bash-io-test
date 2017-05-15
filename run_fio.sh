#!/bin/bash
ulimit -n 65535
ipaddr=$(ip a | awk --posix -F '[ /]+' 'BEGIN{i=0};$0~/[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}/ && $0~/inet/ && $0!~/inet6/ && $0!~/0.0.0.0/ && $0!~/127.0.0.1/ && $0!~/00:00/ {if(i==0) print $3;i++}')
mempath="/dev/shm"
usage()
{
   echo "-i and -p must be input "
   echo "usage $0 -b 4k/50:1024k/50 -e libaio/posixaio/sync -i read/write/rw/randread/randwrite/randrw/randrw/mix -m hdd/ssd -n 8 -t 400 -p /mnt -D dir/raw"
   echo "$0 -i mix -b 4k/50:1024k/30:2048k:20  -e posixaio -m hdd -n 32 -t 1500 -D raw -p /dev/sdf"
   echo "$0 -i mix -p /mnt"
   exit 1
}

[[ $# -lt 4 ]] && usage
[[ -f /proc/sys/fs/aio-max-nr ]]  && echo 360000 > /proc/sys/fs/aio-max-nr

if ! which fio > /dev/zero
then
    yum -y install fio libaio-devel || exit 1
fi


numjobs=8
bssplit="4k/100" # 100% 4k io
fiocfg="${mempath}/fio.cfg"
echo "fio config file:"$fiocfg
media="hdd"
timeout=400
devtype="dir"
ioengine="libaio"
while getopts "b:e:i:m:n:p:t:D:" arg
do
        case $arg in
             b)
                bssplit=$OPTARG
                ;;
             e)
                ioengine=$OPTARG
                ;;
             i)
                export iotype=$OPTARG
                [[ -z $iotype ]] && echo "must input iotype" && exit 1
                ;;
             m)
                media=$OPTARG
                ;;
             n) 
                [[ $OPTAEG -gt 8 ]] && numjobs=$OPTARG
                ;;
             p)
                testpath=$OPTARG
                [[ -z $testpath ]] && echo "must input test destination" && exit 1
                ;;
             t)
                timeout=$OPTARG
                ;;
             D)
                devtype=$OPTARG
                ;;
             ?)
                echo "unkonw argument"
                exit 1
                ;;
        esac
done

sysmem=$(awk '$0~/MemTotal/{printf "%d\n",$(NF-1)/1024/1024*2}' /proc/meminfo)
size=$((${sysmem}/${numjobs}))
cat > $fiocfg << EOF
[rw]
#read,write,rw,randread,randwrite,randrw
rw=${iotype}
size=${size}G
numjobs=${numjobs}
#directory=/tank/192.168.3.2
#filename=/dev/sdxx
#group_reporting
refill_buffers
end_fsync=0
disable_slat=1
exitall
timeout=${timeout}
thread
bssplit=${bssplit}
#direct=1
#bssplit=4k/50:1024k/50
nrfiles=8
ioengine=${ioengine}
EOF

[[ $iotype == "mix" ]] && echo "rwmixread=60" >> $fiocfg && echo "percentage_random=50" >> $fiocfg && sed -i 's/rw=mix/rw=randrw/g' $fiocfg
[[ $media == "hdd" ]] && echo "iodepth=16" >> $fiocfg
[[ $media == "ssd" ]] && echo "iodepth=128" >> $fiocfg
[[ $devtype == "raw" ]] && echo "filename=${testpath}" >> $fiocfg
[[ $devtype == "raw" ]] && [[ ! -f $testpath ]] && echo -e "\033[33mWarnning: could not found the path or device "$testpath"\033[0m"

[[ $devtype == "dir" ]] && [[ ! -d ${testpath}/${ipaddr} ]] && mkdir -p ${testpath}"/"${ipaddr}
[[ $devtype == "dir" ]] && echo directory=${testpath}"/"${ipaddr} >> $fiocfg
fio $fiocfg
