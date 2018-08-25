#!/bin/bash
#
# License:      GNU General Public License (GPL)
# Written by:   Homer Li
#
#	This script is benchmark throughput for your filesystem.
#	If you generate a lot of large files by fio, fio(2.1.10) create files only a single process, the script could save your time. 

#######################################################################

usage() {
	echo "Usage: $0 [-i create path] [-p process number] [-j fio-numjobs] [-n fio-nrfiles] [-s total size] [-t running type read,write,rw]" 1>&2; exit 1;
}

while getopts ":i:p:j:n:s:t:" o; do
    case "${o}" in
        s)
            totalsize=${OPTARG}
            ;;
        p)
            ponum=${OPTARG} #Number of running process in this pool
            ;;
        i)
            initpath=${OPTARG}
            ;;
        j)
            numjobs=${OPTARG} #The generate file could be used by fio ,it 's numjobs for fio, here it  affects file number
            ;;
        n)
            nrfiles=${OPTARG} #same with numjbos
            ;;
        t)
            rtype=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

checkvar () {
	if [ -z $1 ]
	then
		return 1
	fi
}

checksize () {
	if [ -f $1 ]
	then
		filesize=$(stat $1 | awk '$0~/Size/ {printf "%d",$2/1024/1024}') #MiB
		if [[ $filesize -ge $2 ]]
		then
			echo "File exist, don't need generate, "$filesize,$2
			return 1 #not generate
		else
			return 0
		fi
	else
		return 0
	fi
}


if ! checkvar $totalsize
then
	#Triple system memory size
	totalsize=$(awk 'BEGIN{IGNORECASE=1} $0~/memtotal/ {printf "%d\n",$(NF-1)/1024*3}' /proc/meminfo)
fi

if ! checkvar $numjobs
then
	numjobs=12
fi

if ! checkvar $nrfiles
then
	nrfiles=8
fi

if ! checkvar $ponum
then
	ponum=16
fi

if ! checkvar $rtype
then
	rtype="write"
fi

if ! checkvar $initpath
then
	initpath="./"
fi

if ! checkvar $mempath
then
	mempath="/dev/shm"
fi

if checksize $mempath/1G.file 1024
then
	openssl rand -out $mempath/1G.file $(( 1024*1024*1024 ))
fi

ipaddr=$(ip a | awk --posix -F '[ /]+' 'BEGIN{i=0};$0~/[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}/ && $0~/inet/ && $0!~/inet6/ && $0!~/0.0.0.0/ && $0!~/127.0.0.1/ && $0!~/00:00/ {if(i==0) print $3;i++}')

initpath=$initpath"/"$ipaddr

if [ ! -d $initpath ]
then
	mkdir -p $initpath
fi

wfiles () {
	declare -A files

	seqsize=$(awk -v mems="$totalsize" -v numj="$numjobs" -v nrf="$nrfiles" 'BEGIN{printf "%d",mems/numj/nrf+1}')
	for ((j=0; j<$numjobs; j++))
	do
		for ((k=0; k<$nrfiles; k++))
		do
			echo rw.$j.$k" "$seqsize
			key=rw.$j.$k
			value=$seqsize
			files[$key]=$value
		done
	done

	#create files
	for key in ${!files[@]}
	do
		echo ${key} ${files[${key}]} #name and size (xxGB) 1GB per loop
		GBs=$(awk -v size="${files[${key}]}" 'BEGIN{printf "%d", size/1024}')
		MBs=$(awk -v size="${files[${key}]}" 'BEGIN{print size%1024+1}')
		echo $key,$GBs,$MBs #name and size (xxGB) 1GB per loop

		if [ $GBs -gt 0 ]
		then
			for ((i=0;i<=$GBs;i++)) #size+1 so we used <=, not <, file need  be large than
			do
				read -u 6
				{
					if checksize $initpath/$key $((GBs*1024+1024))
					then
						echo "cat $mempath/1G.file >> $initpath/$key"
						cat $mempath/1G.file >> $initpath/$key
					fi
					echo >&6
				} &
			done #create process pool
		elif [ $GBs -eq 0 ] && [ $MBs -gt 0 ]
		then
			read -u 6
			{
				if checksize $initpath/$key $MBs
				then
					echo "dd if=$mempath/1G.file of=$initpath/${key} bs=1M count=$MBs"
					dd if=$mempath/1G.file of=$initpath/${key} bs=1M count=$MBs
				fi
				echo >&6
			} &
		fi
	done
}

rfiles () {
cd $initpath
ls -l | awk '{if(NF>2) print $NF}' | while read line
do
        read -u 6
        {
            if [ -f $line ]
            then
                echo cat $line to /dev/zero
                cat $line > /dev/zero
            fi
            echo >&6

        } &
done
}

cpfiles () {
echo --------cpfiles-----------$initpath
cd $initpath
if [ ! -f $initpath/$line-1 ]
then
	rm -f $initpath/$line-1
fi
#find ./ -type f | awk '{if(NF>2) print $NF}' | while read line
find ./ -type f | while read line
do
    rand=$(openssl rand -hex 8)
    echo -------$line
	read -u 6
	{
		if [ -f $line ]
		then
			echo cat line to $line
			cat $line > $initpath/$line-$rand
		fi
		echo >&6
        } &
done
}

###processes pool var
tmp_fifofile="/tmp/$.fifo"
mkfifo "$tmp_fifofile"
exec 6<>"$tmp_fifofile"
rm $tmp_fifofile

for ((i=0; i<$ponum; i++))
do
    echo
done >&6

case $rtype in
    read)
        rfiles
        ;;
    write)
        wfiles
        ;;
    rw)
        cpfiles
        ;;
    *)
	echo "exit, not running"
        ;;
esac
wait
exec 6>&-
