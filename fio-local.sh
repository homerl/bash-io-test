#!/bin/bash
BASEPATH=$(cat /sources/benchmark/IO/fio-var.conf | awk -F= '$0~/SCPATH/ {print $NF}')
fiovar=$BASEPATH/fio-var.conf
FIOBIN=$(cat $fiovar | awk -F= '$0~/FIOV/ {print $NF}')
memsize=$(cat $fiovar | awk -F= '$0~/MEMSIZE/ {print $NF}')
export PATH=$PATH:$FIOBIN
echo $PATH

ori_aio_max_nr=$(cat /proc/sys/fs/aio-max-nr)
if [ -f /proc/sys/fs/aio-max-nr ]
then
	echo 100000 > /proc/sys/fs/aio-max-nr
fi

ulimit -n 65535

usage()
{
   echo "-s == the path contains fio-var.conf"
   echo "usage $0 directory ioengine devicename eg: $0 -s /mnt/benchmark/IO -i randrw -t raw/dir"
   echo "usage $0 directory ioengine devicename eg: $0 -s config file path -i init/seqr/seqw/seqrw/randr/randw/randrw/mix/lock/psync"
   exit 1
}

if [ $# -lt 2 ]
then
	usage
fi

checkstatus () {
if [ $? -gt 0 ]
then
  echo "Counld not found the cmd"
  exit 2
fi
}

while getopts "s:i:t:h" arg
do
        case $arg in
             s)
                echo "source dir arg:$OPTARG"
                export BASEPATH=$OPTARG
                ;;
             i)
                echo "io type is arg:$OPTARG"
                export IOTYPE=$OPTARG
                ;;
             t)
                echo "device type dir :$OPTARG"
                export DEVTYPE=$OPTARG
                ;;
             h)
		usage
                ;;
             ?)
                echo "unkonw argument"
                exit 1
                ;;
        esac
done

fiovar=$BASEPATH/fio-var.conf
ENGINE=$(cat $fiovar | awk -F= '$0~/ENGINE/ {print $NF}')
DESPATH=$(cat $fiovar | awk -F= '$0~/BENCHPATH/ {print $NF}')
TIMEOUT=$(cat $fiovar | awk -F= '$0~/TIMEOUT/ {print $NF}')
BASEPATH=$(cat $fiovar | awk -F= '$0~/SCPATH/ {print $NF}')
FIOV=$(cat $fiovar | awk -F= '$0~/FIOV/ {print $NF}')
QDEPTH=$(cat $fiovar | awk -F= '$0~/QDEPTH/ {print $NF}')
DIRECTIO=$(cat $fiovar | awk -F= '$0~/DIRECT/ {print $NF}')
CMDPATH=$(cat $fiovar | awk -F= '$0~/SCPATH/ {print $NF}')/$(cat $fiovar | awk -F= '$0~/FIOV/ {print $NF}')
export PATH=$PATH:$CMDPATH

tmpdir=/dev/shm
[[ -d ${tmpdir}/fio ]]  &&  mv /${tmpdir}/fio /${tmpdir}/fio$(date +%Y%m%d-%k%M) && echo "bakcup fio dir"
[[ ! -d ${tmpdir}/fio ]] && mkdir -p ${tmpdir}/fio

which ip
checkstatus

echo $DEVTYPE | grep -i dir && ipaddr=$(ip a | awk --posix -F '[ /]+' 'BEGIN{i=0};$0~/[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}/ && $0~/inet/ && $0!~/inet6/ && $0!~/10.53.27/ && $0!~/10.53.28/ && $0!~/0.0.0.0/ && $0!~/127.0.0.1/ && $0!~/00:00/ {if(i==0) print $3;i++}') && echo $ipaddr && mkdir -p $DESPATH/$ipaddr

numjobs=($(cat $fiovar | awk -F= '$0~/NUMJOBS/ {print $NF}'))
nrfiles=($(cat $fiovar | awk -F= '$0~/NRFILES/ {print $NF}'))
which fio
checkstatus
if [ -f /proc/meminfo ]
then
	mems=$(awk '$0~/MemTotal/{printf "%d\n", $(NF-1)/1000/1000}' /proc/meminfo)
        ((mems=mems*1))
fi

for ((i=0;i<${#numjobs[*]};i++))
do
	tmpvalue=$(($mems/${numjobs[$i]}))
	[[ $tmpvalue -eq 0  ]] && tmpvalue=1
        benchsize[i]=$tmpvalue"G"
done

iodepth=$QDEPTH
rwmixread=50
mixlabel=0
hotlabel=0
seqrand=50
bssplit=(1M/100 4K/100 1k/20:4k/40:47k/20:135k/20)
ioengine=$ENGINE
[[ -z $ipaddr ]] && directory=$DESPATH
echo $DEVTYPE | grep -i dir && [[ ! -z $ipaddr ]] && directory=$DESPATH/$ipaddr
timeout=$TIMEOUT
locklabel=0

if [[ -z $IOTYPE ]]
then
	rwtype=(read);
else
   	 case "$IOTYPE" in
	   	read) rwtype=(read)
	   	;;
	   	write) rwtype=(write)
	   	;;
	   	rw) rwtype=(rw)
	   	;;
	   	randread) rwtype=(randread)
	   	;;
	   	randwrite) rwtype=(randwrite)
	   	;;
	   	randrw) rwtype=(randrw)
	   	;;
	   	mix) rwtype=(randrw);mixlabel=1
	   	;;
	   	lock) rwtype=(randrw);mixlabel=1;locklabel=1
	   	;;
	   	psync) rwtype=(randrw);psynclabel=1;locklabel=1;bsvar=2
	   	;;
	   	init) rwtype=(read randread);timeout=1
	   	;;
	 esac
fi

for ((i=0;i<${#rwtype[*]};i++))
do
	for ((j=0;j<${#numjobs[*]};j++))
	do
	rm -f /$tmpdir/fio.cfg

cat >> /$tmpdir/fio.cfg << EOF
[rw]
rw=${rwtype[$i]}
ioengine=$ioengine
iodepth=$iodepth
direct=$DIRECTIO
EOF

echo ${rwtype[$i]} | grep rw
if [ $? -eq 0 ]
then
cat >> /$tmpdir/fio.cfg << EOF
rwmixread=$rwmixread
EOF
	 fi

echo ${rwtype[$i]} | grep rand
if [[ $? -eq 0 ]] && [[ ! $bsvar -eq 2 ]]
then
	bsvar=1
else
	bsvar=0
fi

cat >> /$tmpdir/fio.cfg << EOF
norandommap=1
size=${benchsize[$j]}
numjobs=${numjobs[$j]}
group_reporting
refill_buffers
##end_fsync=1 ##because not support ftruncate
disable_slat=1
exitall
time_based
runtime=$timeout
#thread
#write_bw_log=/$tmpdir/fio/fio_${rwtype[$i]}_${numjobs[$j]}.write_bw
#write_lat_log=/$tmpdir/fio/fio_${rwtype[$i]}_${numjobs[$j]}.write_lat
#write_iops_log=/$tmpdir/fio/fio_${rwtype[$i]}_${numjobs[$j]}.write_iops
EOF

[[ -z $DEVTYPE ]] && exit 1
echo $DEVTYPE | grep -i raw && echo filename=${directory} >> $tmpdir/fio.cfg
echo $DEVTYPE | grep -i dir && echo directory=${directory} >> $tmpdir/fio.cfg
if [ $mixlabel -eq 1 ]
then
	bsvar=1
	echo nrfiles=${nrfiles[1]} | tee -a /$tmpdir/fio.cfg
	echo bssplit=${bssplit[1]} | tee -a /$tmpdir/fio.cfg
	echo percentage_random=$seqrand | tee -a /$tmpdir/fio.cfg
fi
if [ $locklabel -eq 1 ]
then
	bsvar=1
	echo lockfile=readwrite | tee -a /$tmpdir/fio.cfg
fi
if [ $psynclabel -eq 1 ]
then
	bsvar=2
	echo lockfile=readwrite | tee -a /$tmpdir/fio.cfg
	echo offset=2% | tee -a /$tmpdir/fio.cfg
	echo buffer_pattern=0xdeadface | tee -a /$tmpdir/fio.cfg
	echo offset_increment=33 | tee -a /$tmpdir/fio.cfg
	echo write_barrier=8 | tee -a /$tmpdir/fio.cfg
	#echo sync_file_range=wait_before | tee -a /$tmpdir/fio.cfg
	#echo mem_align=4 | tee -a /$tmpdir/fio.cfg
        sed -i 's/libaio/psync/g' /$tmpdir/fio.cfg
fi
#if [ $hotlabel -eq 1 ]
#then
#	bsvar=1
#	echo random_distribution=zipf:1.2 | tee -a /$directory/fio.cfg
#fi

if [ $bsvar -eq 0 ]
then
	echo bssplit=${bssplit[0]} | tee -a /$tmpdir/fio.cfg
	echo nrfiles=${nrfiles[0]} | tee -a /$tmpdir/fio.cfg
elif [ $bsvar -eq 1 ]
then
	echo bssplit=${bssplit[1]} | tee -a /$tmpdir/fio.cfg
	echo nrfiles=${nrfiles[1]} | tee -a /$tmpdir/fio.cfg
elif [ $bsvar -eq 2 ]
then
	echo bssplit=${bssplit[2]} | tee -a /$tmpdir/fio.cfg
	#echo bssplit=${bssplit[1]} | tee -a /$tmpdir/fio.cfg
fi

	 echo "clear cache"
	 echo 3 > /proc/sys/vm/drop_caches
	 echo ${rwtype[$i]} | grep rand
	 if [ $? -eq 0 ]
	 then
		#cat /$tmpdir/fio.cfg; sleep 3
		if [ $mixlabel -eq 1 ]
		then
			fio /$tmpdir/fio.cfg 2>&1 | tee /$tmpdir/fio/fio_${IOTYPE}_${numjobs[$j]} #mix mode is randrw
		else
			fio /$tmpdir/fio.cfg 2>&1 | tee /$tmpdir/fio/fio_${IOTYPE}_${numjobs[$j]}
		fi
		echo
	 else
		#cat /$tmpdir/fio.cfg; sleep 3
		fio /$tmpdir/fio.cfg 2>&1 | tee /$tmpdir/fio/fio_${IOTYPE}_${numjobs[$j]}
		echo
	 fi
	done
done
echo $ori_aio_max_nr > /proc/sys/fs/aio-max-nr
