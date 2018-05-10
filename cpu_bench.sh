#!/bin/bash
###########################################################################
# Script:       $0
# Author:       Homer Li
# Modify:       Homer Li
# Date:         2015-04-27
# Update:       2018-05-09
# Email:        
# Usage:        $0
# Discription:  cpu/mem subsystem benchmark
#
###########################################################################
# 2018-05-08 update cd-hit and samtools, smcpp version, add megahit and mecat2pw test
# 2018-05-08 add numa node 0 test replace single core test, because single core too slow
# 2018-05-09 memory size check , filesytem free capacity check, add minimap2 test
# 2018-05-10 add gcc test
#add pmbw benchmark
export BASEPATH=/sources/benchmark
export SOCKCPU=$(grep -i "physical id" /proc/cpuinfo | sort -u | wc -l )
export TCPU=$(lscpu | grep -i thread |  awk '{print $NF}')
export NCPU=$(grep -c processor /proc/cpuinfo)
export NOHTN=$(($NCPU/$TCPU)) #physical core number, no hyper threading
export NUMANUM=$(numactl --hardware | tail -n 1 | awk -F: '{print $1}') # 2 way/4 way/8 way numa
[[ $NUMANUM -eq 0 ]] && export NUMANUM=1
#export NAMDPATH=$BASEPATH/cpu/NAMD/NAMD_2.9_Linux-x86_64-multicore
export NPBPATH=$BASEPATH/cpu/NPB3.3.1/NPB3.3-OMP
#export CRAFTYPATH=$BASEPATH/cpu/crafty-24.1
export PMBWPATH=$BASEPATH/cpu/pmbw-0.6.2
export STREAMPATH=$BASEPATH/cpu/stream
export LINPACKPATH=$BASEPATH/cpu/l_mklb_p_2017.2.015/benchmarks_2017/linux/mkl/benchmarks/linpack
#export BLASRPATH=$BASEPATH/cpu/BLASR/blasr_el6
#export PMBWMIN=33554432
#export PMBWMAX=4294967296
export GOTESTPATH=$BASEPATH/cpu/go
#export CRAYPATH=$BASEPATH/cpu/c-ray-1.1
export RANDOMDATA=random-data
export MEMPATH=/dev/shm
export CPUMAXPRIME=900000
export SMCPPATH=$BASEPATH/cpu/smcpp
#export MATRIXNUM="3000 4000 5000"
export DEVZERO=/dev/zero
export MEMSIZE=$((1024*1024*$(awk '$0~/MemTotal/{printf "%d\n", $(NF-1)/1024}' /proc/meminfo)/10*8))
export mem40_MB=$(awk '$0~/MemTotal/ {printf "%d\n", $(NF-1)*0.4/1024}' /proc/meminfo)
export nohtn=$(for ((i=0;i<$(grep -c processor /proc/cpuinfo);i++)); do cat /sys/devices/system/cpu/cpu$i/cache/index2/shared_cpu_list; done | awk -F, '{a[$1]=$0} END{count=0;for (i in a) {if(count==0) {printf i} else {printf ","i};count++ } }')
(cpupower idle-set -d 4 && cpupower idle-set -d 3 && cpupower idle-set -d 2 && cpupower  frequency-set -g performance) > /dev/zero 2>&1
usage()
{
   echo "usage $0 program-name eg: $0 init/gz/openssl/npb/pi/cd-hit/samtools/stream/linpack/smcpp/megahit/mecat2pw"
   echo $0" all"
   exit 1
}

checkstatus () {
if [ $? -gt 0 ]
then
  echo "Run cmd fail"
  exit 2
fi
}

checkcmd () {
	which $1
	if [ $? -gt 0 ]
	then
		echo "Could not found "$1
		exit 2
	fi
}

checkmem () {
    export totalmem=$(awk '$0~/MemTotal/ {printf "%d\n", $(NF-1)/1024/1024}' /proc/meminfo)
}

#NAMD()
#{
#echo "run NAMD..."
#cd $NAMDPATH
#./namd2 +p$1 +setcpuaffinity ../apoa1/apoa1.namd | grep "Benchmark time" | tail -1 |  awk '{print "single core namd s/step:"$6}'
#}

#BLASR()
#{
#echo "run BLASR..."
#cd $BLASRPATH
#sh ./export
#}

GZ()
{
echo "run gz compress..."
cd $MEMPATH
time ( pigz -11 -c $RANDOMDATA > ${RANDOMDATA}.gz) | awk '$0~/real/{print $2}'
#rm -f $MEMPATH/*
}

#SYSBENCH()
#{
#echo "run sysbench..."
#sysbench --num-threads=$NCPU --test=cpu --cpu-max-prime=$CPUMAXPRIME run | awk '$0~/total time:/{print "sysbench total time:"$NF}'
#sysbench --num-threads=$NOHTN --test=cpu --cpu-max-prime=$CPUMAXPRIME run | awk '$0~/total time:/{print "No HT sysbench total time:"$NF}'
#}

OPENSSL()
{
echo "run all openssl..."
openssl speed aes-256-ige whirlpool des-ede3 -multi $NCPU  >/tmp/opensslog 2>&1
tail -n 3 /tmp/opensslog | awk '{if ($0~/aes-256/) print "aes-256-ige 8192:"$NF; if ($0~/whirlpool/) print "whirlpool 8192:"$NF;  if ($0~/ede3/) print "des-ede3 8192:"$NF}'
echo ---node0-openssl---
[[ $(($NOHTN/$NUMANUM)) -eq $NOHTN ]] && echo only single node,exit numa test || numactl -N 0 -m 0 openssl speed aes-256-ige whirlpool des-ede3 -multi $(($NOHTN/$NUMANUM))  >/tmp/opensslog 2>&1
tail -n 3 /tmp/opensslog | awk '{if ($0~/aes-256/) print "single core aes-256-ige 8192:"$NF; if ($0~/whirlpool/) print "single core whirlpool 8192:"$NF;  if ($0~/ede3/) print "single core des-ede3 8192:"$NF}'
}

#CRAFTY()
#{
#echo "run crafty..."
#cd $CRAFTYPATH
#./crafty smpmt=$NCPU bench end |  awk '$0~/Raw nodes per second/{print "Crafty raw node per second:"$NF}'
#}

PMBW()
{
echo "run PMBW..."
cd $PMBWPATH
./pmbw -p $NCPU -P $NCPU -f ScanRead128PtrSimpleLoop p -f ScanWrite128PtrSimpleLoop -M $MEMSIZE 2>&1  | awk -F '[= \t]+' '$0~/bandwidth/{print "all_cpu_"$10,$14,$(NF-2)/1024/1024/1024" GB/s"}'
numactl --physcpubind=${nohtn} ./pmbw -p $NOHTN -P $NOHTN -f ScanRead128PtrSimpleLoop p -f ScanWrite128PtrSimpleLoop -M $MEMSIZE 2>&1 | awk -F '[= \t]+' '$0~/bandwidth/{print "noht_cpu_"$10,$14,$(NF-2)/1024/1024/1024" GB/s"}'
./pmbw -p 1 -P 1 -f ScanRead128PtrSimpleLoop p -f ScanWrite128PtrSimpleLoop -M $MEMSIZE 2>&1 | awk -F '[= \t]+' '$0~/bandwidth/{print "single_core_"$10,$14,$(NF-2)/1024/1024/1024" GB/s"}'
}

#CRAY()
#{
#echo "run CRAY..."
#cd $CRAYPATH
#cat sphfract | ./c-ray-mt -t $NCPU -s 3840x2160 -r 8  2>&1 | awk -F '[ :]+' '$0~/Rendering took/ {print "C-ray rendering took seconds:"$3}'
#}


PI()
{
cd $GOTESTPATH
echo "all compute pi..."
echo -n "pi 600G:";./600G-pi | awk -F '[ :]+' '$0~/spend time/{ print $NF}'
}

MATRIX()
{
cd $GOTESTPATH
echo "run MATRIX..."
echo -n "matrix:";./matrix_system $MATRIXNUM | awk -F '[ :]+' '$0~/Time-consuming/{ print $NF}'
echo
}


NPB()
{
echo "run NPB..."
cd $NPBPATH
for i in $(ls bin/); do echo -n $i" Mop/s":;bin/$i | awk '$0~/Mop\/s total/{print $NF}';echo ; done
for i in $(ls bin/); do echo -n "no ht "$i" Mop/s":;numactl --physcpubind=${nohtn} bin/$i | awk '$0~/Mop\/s total/{print $NF}';echo ; done
}

STREAM()
{
mem=$(awk '$0~/MemTotal/ {printf "%d\n", $(NF-1)/1024/1024/10*8*44599177}' /proc/meminfo)
sed "s/524335808/${mem}/" /sources/benchmark/cpu/stream/stream.c
echo "run STREAM..."
cd $STREAMPATH
make;bin/stream 2>&1 | awk '$0~/Copy/||$0~/Scale/||$0~/Add/||$0~/Triad/ {print $1": "$2" GB/s"}'
make > /dev/zero;
bin/stream 2>&1
echo "---no-ht---"
numactl --physcpubind=${nohtn} bin/stream 2>&1
echo "----node0---"
[[ $(($NOHTN/$NUMANUM)) -eq $NOHTN ]] && echo only single node,exit numa test || numactl -N 0 -m 0 bin/stream 2>&1
echo "---single-core---"
numactl --physcpubind=3 -m 0 bin/stream 2>&1
}

LINPACK()
{
echo "run LINPACK..."
cd $LINPACKPATH
./xlinpack_xeon64 < lininput_xeon64_ao | grep -A 6 "Performance Summary" |  awk '$0~/59392/||$0~/47104/||$0~/51200/ {print "size: "$1, "No-HT(auto disable) Average (GFLops): "$4}'
#45056 47104# problem sizes
#45120 47168# leading dimensions
}

SMCPP()
{
  cd $SMCPPATH
  echo -n "SMC++ output: "
  releasever=$(awk  '{print $(NF-1)}' /etc/redhat-release | grep -Eo ^.)
  rsync -avP data/Med-POP18_AS_7 $MEMPATH
  cd  /sources/benchmark/cpu/smcpp
  (time /sources/benchmark/cpu/smcpp/smcpp-1.13.1/bin/smc++ estimate --thinning 40 --t1 100 --tK 500 --regularization-penalty 9 3e-9 ${MEMPATH}/Med-POP18_AS_7/Med.NewChr{1..20}.smc.gz)
  rm -rf ${MEMPATH}/Med-POP18_AS_7
}


SAMTOOLS()
{
echo "-----------install-samtools-------------------"
cd /dev/shm
axel -n 4 -a http://10.0.0.10/source/benchmark/cpu/samtools/samtools-1.8.tar.bz2
tar xjvf samtools-1.8.tar.bz2
cd samtools-1.8
./configure --enable-plugins --enable-libcurla --prefix=/dev/shm/samtools-1.8  && make all all-htslib  && make install install-htslib > /dev/zero 2>&1
echo "run samtools..."
if [ ! -f $MEMPATH/Bubalus01.rmdup.bam ]
then
   cd $MEMPATH && axel -n 4 -a http://10.0.0.10/sources/benchmark/cpu/samtools/data/bam/Bubalus01.rmdup.bam
fi
samtoolsbin=/sources/benchmark/cpu/samtools/samtools-1.8/samtools
echo --------no-ht---------
(time numactl --physcpubind=${nohtn} $samtoolsbin sort -@ $NOHTN  ${MEMPATH}/Bubalus01.rmdup.bam > /dev/zero 2>&1) | awk '$0~/real/{print $2}'
echo --------node0---------
[[ $(($NOHTN/$NUMANUM)) -eq $NOHTN ]] && echo only single node,exit numa test || (time numactl -N 0 -m 0 $samtoolsbin sort -@ $(($NOHTN/$NUMANUM))  ${MEMPATH}/Bubalus01.rmdup.bam > /dev/zero 2>&1) | awk '$0~/real/{print $2}'
#rm -f $MEMPATH"/Bubalus01.rmdup.bam"
}

CD-HIT()
{
echo "-------------install-cd-hit---------------"
cd /tmp
axel -n 4 -a http://10.0.0.10/source/benchmark/cpu/cd-hit/cd-hit-v4.6.8-2017-1208-source.tar.gz > /dev/zero 2>&1
tar xzf cd-hit-v4.6.8-2017-1208-source.tar.gz  > /dev/zero 2>&1
cd cd-hit-v4.6.8-2017-1208
make clean
make openmp=yes
chmod 755 /tmp/cd-hit-v4.6.6-2016-0711/cd-hit-est

cdhit_file=longest_orfs.cds.top_longest_5000
echo "run cd-hit..."
cd $MEMPATH
if [ ! -f $MEMPATH"/"$cdhit_file ]
then
  axel -n 4 -a http://10.0.0.10/source/benchmark/cpu/cd-hit/data/$cdhit_file
fi
echo --------no-ht---------
[[ $(($NOHTN/$NUMANUM)) -eq $NOHTN ]] && echo only single node,exit numa test || (time /tmp/cd-hit-v4.6.6-2016-0711/cd-hit-est -i $cdhit_file -o test -c 0.8 -M $mem40_MB -T $NOHTN) 2>&1 | awk '$0~/real/{print $2}'
rm -f $MEMPATH"/"$cdhit_file
}

MEGAHIT()
{
tmpfree=$(df -h /tmp | awk -F'[ G]+' '$0~/\// {print $(NF-2)}')
echo "-------------megahit test---------------"
[[ $tmpfree -lt 120 ]] && echo "no enough capacity in /tmp" && return 0
megahit_file1=k67.bubble_seq.fa
megahit_file2=k67.contigs.fa
megahit_file3=reads.lib.bin
temppath=/tmp/megahit
[[ ! -d $temppath ]] && mkdir $temppath
cd $temppath
[[ ! -f $temppath"/"$megahit_file1 ]] && axel -n 4 -a http://10.0.0.10/source/benchmark/cpu/megahit/$megahit_file1
[[ ! -f $temppath"/"$megahit_file2 ]] && axel -n 4 -a http://10.0.0.10/source/benchmark/cpu/megahit/$megahit_file2
[[ ! -f $temppath"/"$megahit_file3 ]] && axel -n 4 -a http://10.0.0.10/source/benchmark/cpu/megahit/$megahit_file3
echo ----------megahit all-------------
echo /sources/benchmark/cpu/megahit/megahit_v1.1.3_LINUX_CPUONLY_x86_64-bin/megahit_asm_core iterate -c ${temppath}/${megahit_file2} -b ${temppath}/${megahit_file1} -k 67  -s 10 -t $NCPU -o $temppath -r ${temppath}/${megahit_file3} -f binary
(time /sources/benchmark/cpu/megahit/megahit_v1.1.3_LINUX_CPUONLY_x86_64-bin/megahit_asm_core iterate -c ${temppath}/${megahit_file2} -b ${temppath}/${megahit_file1} -k 67  -s 10 -t $NCPU -o $temppath -r ${temppath}/${megahit_file3} -f binary ) 2>&1 | awk '$0~/real/{print $2}'
echo ----------numa0------------
[[ $(($NOHTN/$NUMANUM)) -eq $NOHTN ]] && echo only single node,exit numa test || (time numactl -m 0 -N 0 /sources/benchmark/cpu/megahit/megahit_v1.1.3_LINUX_CPUONLY_x86_64-bin/megahit_asm_core iterate -c ${temppath}/${megahit_file2} -b ${temppath}/${megahit_file1} -k 67  -s 10 -t $(($NOHTN/$NUMANUM)) -o $temppath -r ${temppath}/${megahit_file3} -f binary ) 2>&1 | awk '$0~/real/{print $2}'
rm -f /tmp/*
}


MECAT2PW()
{
tmpfree=$(df -h /tmp | awk -F'[ G]+' '$0~/\// {print $(NF-2)}')
[[ $tmpfree -lt 50 ]] && echo "no enough capacity in /tmp" && return 0
echo "-------------mecat2pw test---------------"
cd /tmp
mecat2pwfile=all.subreads.fasta
[[ ! -f $MEMPATH"/"$mecat2pwfile ]] && axel -n 4 -a http://10.0.0.10/source/benchmark/cpu/MECAT/all.subreads.fasta
outdir=/sources/test100
(time /sources/benchmark/cpu/MECAT/MECAT/Linux-amd64/bin/mecat2pw -j 0 -d /sources/test100/$mecat2pwfile -o /dev/shm/all.subreads.fasta -w mecat_reslut -t $NCPU) 2>&1 | awk '$0~/real/{print $2}'
echo -----------node0---------------
#echo time numactl -m 0 -N 0 /sources/benchmark/cpu/MECAT/MECAT/Linux-amd64/bin/mecat2pw -j 0 -d /sources/test100/$mecat2pwfile -o /dev/shm/all.subreads.fasta -w mecat_reslut -t $(($NOHTN/$NUMANUM))
[[ $(($NOHTN/$NUMANUM)) -eq $NOHTN ]] && echo only single node,exit numa test || (time numactl -m 0 -N 0 /sources/benchmark/cpu/MECAT/MECAT/Linux-amd64/bin/mecat2pw -j 0 -d /sources/test100/$mecat2pwfile -o /dev/shm/all.subreads.fasta -w mecat_reslut -t $(($NOHTN/$NUMANUM))) 2>&1 | awk '$0~/real/{print $2}'
rm -f /tmp/*
}


MINIMAP2()
{
tmpfree=$(df -h /tmp | awk -F'[ G]+' '$0~/\// {print $(NF-2)}')
[[ $tmpfree -lt 130 ]] && echo "no enough capacity in /tmp" && return 0
temppath=/tmp
[[ ! -d ${temppath} ]] && mkdir -p ${temppath}
cd $temppath
[[ ! -f ${temppath}/Nanopore.fastq.gz ]] && axel -n 4 -a http://10.0.0.10/source/benchmark/cpu/minimap2/test_data/Nanopore.fastq.gz
echo ---minimap2 for Nanopore Direct RNA-seq------------
(time /sources/benchmark/cpu/minimap2/minimap2 ${temppath}/Nanopore.fastq.gz ${temppath}/Nanopore.fastq.gz -ax splice -k14 -uf -t $NCPU) 2>&1 | awk '$0~/real/{print $2}'
echo ---minimap2 node0------------
[[ $(($NOHTN/$NUMANUM)) -eq $NOHTN ]] && echo only single node,exit numa test || (time numactl -m 0 -N 0 /sources/benchmark/cpu/minimap2/minimap2 ${temppath}/Nanopore.fastq.gz ${temppath}/Nanopore.fastq.gz -ax splice -k14 -uf -t $(($NOHTN/$NUMANUM))) 2>&1 | awk '$0~/real/{print $2}'
rm -f /tmp/minipath2/*
}

GCC()
{
tmpfree=$(df -h /tmp | awk -F'[ G]+' '$0~/\// {print $(NF-2)}')
[[ $tmpfree -lt 4 ]] && echo "no enough capacity in /tmp" && return 0
temppath=/tmp
cd $temppath ; pwd
[[ ! -f ${temppath}/gcc-5.5.0.tar.xz ]] && axel -n 4 -a http://10.0.0.10/sources/benchmark/src/gcc-5.5.0.tar.xz
yum install -y gmp-devel mpfr-devel libmpc-devel
tar xJvf gcc-5.5.0.tar.xz > /dev/zero
cd /${temppath}/gcc-5.5.0
make clean
./configure --disable-multilib  --enable-languages=c,c++ --enable-libstdcxx-threads  --enable-libstdcxx-time  --enable-shared  --enable-__cxa_atexit  --disable-libunwind-exceptions --disable-libada  --host x86_64-redhat-linux-gnu  --build x86_64-redhat-linux-gnu  --with-default-libstdcxx-abi=gcc4-compatible
echo --------make gcc------
(time make -j $NCPU > /dev/zero) 2>&1 | awk '$0~/real/{print $2}'
}

INITDATA()
{
yum -y groupinstall "Development Tools" 2 > $DEVZERO
checkstatus
yum -y install gcc-c++ p7zip sysbench make gcc zlib-devel ncurses-devel numactl gcc-gfortran pigz 2 > $DEVZERO
checkstatus

#checkcmd 7za
#checkcmd sysbench
checkcmd pigz
checkcmd openssl
checkcmd gcc
checkcmd make
checkcmd swapoff
checkcmd tee

swapoff -a


rm -f $MEMPATH/*
echo "generate random data..."
for ((i=0;i<=1;i++))
do
    openssl rand -out $MEMPATH/test$i -base64 $((2**30 *3 /4))
done
cat $MEMPATH/test* > $MEMPATH/$RANDOMDATA
rm -rf $MEMPATH/test*

echo "make pmbw..."
cd $PMBWPATH
make clean
./configure
make

#echo "make CRAY..."
#cd $CRAYPATH
#make clean
#make

#echo "make crafty..."
#cd $CRAFTYPATH
#make clean
#make target=UNIX  CC=gcc CXX=g++ opt='-DTEST -DINLINEASM -DPOPCNT -DCPUS=$NCPU'  CFLAGS='-Wall -pipe -O3 -fprofile-arcs -pthread'  CXFLAGS='-Wall -pipe -O3 -fprofile-arcs -pthread'  LDFLAGS=' -lstdc++ -fprofile-arcs -pthread -lstdc++ ' crafty-make > $DEVZERO 2>&1

echo "make NPB..."
cd $NPBPATH
rm -f bin/*
make clean
echo "" >  config/suite.def
cat >>  config/suite.def<<EOF
# config/suite.def
# This file is used to build several benchmarks with a single command.
# Typing "make suite" in the main directory will build all the benchmarks
# specified in this file.
# Each line of this file contains a benchmark name and the class.
# The name is one of "cg", "is", "dc", "ep", mg", "ft", "sp",
#  "bt", "lu", and "ua".
# The class is one of "S", "W", "A" through "E"
# (except that no classes C,D,E for CD and no class E for IS and UA).
# No blank lines.
# The following example builds sample sizes of all benchmarks.
#ft      D
mg      D
#sp      D
#lu      D
#bt      D
#is      D
ep      D
cg      D
#ua      D
EOF
make suite > $DEVZERO 2>&1

}

main()
{
INITDATA
SYSBENCH
OPENSSL
NPB
PI
STREAM
LINPACK
SMCPP
PMBW
SAMTOOLS
CD-HIT
GZ
GCC
checkmem && [[ $totalmem -gt 60 ]] && MEGAHIT
checkmem && [[ $totalmem -gt 60 ]] && MECAT2PW
checkmem && [[ $totalmem -gt 45 ]] && MINIMAP2
}


case $1 in
	init)
		INITDATA
		;;
	gz)
		GZ
		;;
	pmbw)
		PMBW
		;;
	sysbench)
		SYSBENCH
		;;
	openssl)
		OPENSSL
		;;
	npb)
		NPB
		;;
	pi)
		PI
		;;
	cd-hit)
		CD-HIT
		;;
	samtools)
		SAMTOOLS
		;;
	stream)
		 STREAM
		;;
	linpack)
		LINPACK #test program is no ht mode
		;;
	smcpp)
		SMCPP
		;;
	megahit)
		checkmem && [[ $totalmem -gt 60 ]] && MEGAHIT
		;;
	mecat2pw)
		checkmem && [[ $totalmem -gt 60 ]] && MECAT2PW
		;;
	minimap2)
		checkmem && [[ $totalmem -gt 45 ]] && MINIMAP2
		;;
	gcc)
		GCC
		;;
	all)
		main 2>&1 | tee /tmp/cpu-bench
		;;
	-h)
		usage
		;;
	-help)
		usage
		;;
	*)
		#main | awk --posix '$NF~/[0-9]{2}/' | tee /tmp/cpu-bench
		main | tee /dev/shm/cpu-bench
                usage
		;;
esac

swapon -a
