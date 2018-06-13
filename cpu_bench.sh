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
#!/bin/bash
#
#It contains NAS parallel benchmark, NAMD, sysbench(CPU), Openssl, pmbw, 7-zip, and some golang programs(pi, matrix compute)
#The script will test cpu and memroy perforamnce in a compute node.
#if you have any question , please contact liyan2@genomics.cn

#add pmbw benchmark
export BASEPATH=/sources/benchmark
export SOCKCPU=$(grep -i "physical id" /proc/cpuinfo | sort -u | wc -l )
export TCPU=$(lscpu | grep -i thread |  awk '{print $NF}')
export NCPU=$(grep -c processor /proc/cpuinfo)
export NOHTN=$(($NCPU/$TCPU)) #physical core number, no hyper threading
export NUMANUM=$(numactl --hardware | tail -n 1 | awk -F: '{print $1}') # 2 way=1/4 way=3/8 way numa
[[ $NUMANUM -eq 0 ]] && unset NUMANUM
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
   echo "usage $0 program-name eg: $0 init/gz/openssl/npb/pi/cd-hit/samtools/stream/linpack/smcpp/megahit/mecat2pw/minimap2"
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

checktemppath () {
strlen=$(uname -r | awk -F. '$1>=3 && $2>=10{print $0}')
if [[ ${#strlen} -gt 2 ]]
then
  runsize=$1
  [[ -z $runszie ]] && export runsize=100
  declare -A arr
  for temppath in {/dev/shm,/tmp,/home}
    do
       tmpfree=$(df $temppath | awk -F'[ G]+' '$0~/\// {print $(NF-2)}')
       arr+=( [$temppath]=$tmpfree)
       if [[ $tmpfree -gt $runsize ]]
       then
           echo "enough ,the path is "${temppath}
           echo "export $temppath, free size:"$tmpfree
       fi
    done
    maxpath="/tmp"
    maxsize=$1
  for j in "${!arr[@]}"
  do
    echo "key  : $j"
    echo "value: ${arr[$j]}"
    [[ ${arr[$j]} -gt $maxsize ]] && export maxpath=$j && export maxsize=${arr[$j]}
  done
  echo "output:---"$maxpath"---maxsize:"$maxsize
else
  export maxpath=/tmp
fi
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
cd $MEMPATH
echo "------------running pigz all cores------------"
time ( pigz -11 -c $RANDOMDATA > ${RANDOMDATA}.gz) | awk '$0~/real/{print $2}'
cd  ${MEMPATH}; rm -f ${RANDOMDATA}.gz
}

#SYSBENCH()
#{
#echo "run sysbench..."
#sysbench --num-threads=$NCPU --test=cpu --cpu-max-prime=$CPUMAXPRIME run | awk '$0~/total time:/{print "sysbench total time:"$NF}'
#sysbench --num-threads=$NOHTN --test=cpu --cpu-max-prime=$CPUMAXPRIME run | awk '$0~/total time:/{print "No HT sysbench total time:"$NF}'
#}

OPENSSL()
{
echo "--------------running openssl for all cores--------------"
openssl speed aes-256-ige whirlpool des-ede3 -multi $NCPU  >/tmp/opensslog 2>&1
tail -n 3 /tmp/opensslog | awk '{if ($0~/aes-256/) print "aes-256-ige 8192:"$NF; if ($0~/whirlpool/) print "whirlpool 8192:"$NF;  if ($0~/ede3/) print "des-ede3 8192:"$NF}'
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
echo "--------running all compute pi---------"
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
echo "-----runnning NPB-----"
cd $NPBPATH
for i in $(ls bin/); do echo -n $i" Mop/s":;bin/$i | awk '$0~/Mop\/s total/{print $NF}';echo ; done
for i in $(ls bin/); do echo -n "no ht "$i" Mop/s":;numactl --physcpubind=${nohtn} bin/$i | awk '$0~/Mop\/s total/{print $NF}';echo ; done
}

STREAM()
{
mem=$(awk '$0~/MemTotal/ {printf "%d\n", $(NF-1)/1024/1024/10*8*44599177}' /proc/meminfo)
rsync -avP /sources/benchmark/cpu/stream/stream.c_bak /sources/benchmark/cpu/stream/stream.c
sed -i "s/524335808/${mem}/" /sources/benchmark/cpu/stream/stream.c
echo "run STREAM..."
cd $STREAMPATH
make > /dev/zero;
bin/stream 2>&1
echo "---running stream no-ht---"
numactl --physcpubind=${nohtn} bin/stream 2>&1
echo "----running stream in single socket---"
[[ ! -z $NUMANUM ]] && echo only single node,exit numa test || numactl -N 0 -m 0 bin/stream
echo "---running stream in single-core---"
numactl --physcpubind=3 bin/stream 2>&1
}

LINPACK()
{
echo "run LINPACK..."
cd $LINPACKPATH
echo ---------running linpack all cores-----------
./xlinpack_xeon64 < lininput_xeon64_ao | grep -A 6 "Performance Summary" |  awk '$0~/59392/||$0~/47104/||$0~/51200/ {print "size: "$1, "No-HT(auto disable) Average (GFLops): "$4}'
#45056 47104# problem sizes
#45120 47168# leading dimensions
}

SMCPP()
{
  checktemppath 24565756
  cd $SMCPPATH
  echo -n "SMC++ output: "
  rsync -avP data/Med-POP18_AS_7 $MEMPATH > /dev/zero
  strlen=$(uname -r | awk -F. '$1>=3 && $2>=10{print $0}')
  if [[ ${#strlen} -gt 2 ]]
  then
  echo ----------------running SMCPP all cores---------------
     rsync -avP /sources/benchmark/cpu/smcpp/smcpp-1.13.1.tar.xz $maxpath > /dev/zero
     cd $maxpath ; tar xJvf smcpp-1.13.1.tar.xz > /dev/zero
     echo "${maxpath}/smcpp-1.13.1/bin/smc++ estimate --thinning 40 --t1 100 --tK 500 --regularization-penalty 9 3e-9 ${MEMPATH}/Med-POP18_AS_7/Med.NewChr{1..20}.smc.gz"
     (time ${maxpath}/smcpp-1.13.1/bin/smc++ estimate --thinning 40 --regularization-penalty 9 3e-9 ${MEMPATH}/Med-POP18_AS_7/Med.NewChr{1..20}.smc.gz >/dev/zero) 2>/tmp/SMCPP.log
  echo ----------------running SMCPP in single socket---------------
     echo "${maxpath}/smcpp-1.13.1_el6/bin/smc++ estimate --thinning 40 --regularization-penalty 9 3e-9 ${MEMPATH}/Med-POP18_AS_7/Med.NewChr{1..20}.smc.gz"
     [[ ! -z $NUMANUM ]] && (time numactl -N 0 -m 0 ${maxpath}/smcpp-1.13.1/bin/smc++ estimate --thinning 40 --regularization-penalty 9 3e-9 ${MEMPATH}/Med-POP18_AS_7/Med.NewChr{1..20}.smc.gz > /dev/zero) 2>>/tmp/SMCPP.log
  else
     echo ----------------running SMCPP all cores---------------
     rsync -avP /sources/benchmark/cpu/smcpp/smcpp-1.13.1_el6.tar.xz $maxpath > /dev/zero
     cd $maxpath ; tar xJvf smcpp-1.13.1_el6.tar.xz > /dev/zero
     (time ${maxpath}/smcpp-1.13.1_el6/bin/smc++ estimate --thinning 40 --regularization-penalty 9 3e-9 ${MEMPATH}/Med-POP18_AS_7/Med.NewChr{1..20}.smc.gz > /dev/zero) 2>/tmp/SMCPP.log
  echo ----------------running SMCPP in single socket---------------
     [[ ! -z $NUMANUM ]] && (time numactl -N 0 -m 0 ${maxpath}/smcpp-1.13.1_el6/bin/smc++ estimate --thinning 40 --regularization-penalty 9 3e-9 ${MEMPATH}/Med-POP18_AS_7/Med.NewChr{1..20}.smc.gz > /dev/zero)  2>/tmp/SMCPP.log
  fi
#  rm -rf ${MEMPATH}/Med-POP18_AS_7
}


SAMTOOLS()
{
echo "-----------install-samtools-------------------"
checktemppath 24565756
cd $maxpath
[[ -f ${maxpath}/samtools-1.8.tar.bz2 ]] || rsync -avP /sources/benchmark/cpu/samtools/samtools-1.8.tar.bz2 $maxpath > /dev/zero
[[ -f ${maxpath}/bcftools-1.8.tar.bz2 ]] || rsync -avP /sources/benchmark/cpu/samtools/bcftools-1.8.tar.bz2 $maxpath > /dev/zero
tar xjvf bcftools-1.8.tar.bz2 > /dev/zero
cd bcftools-1.8; pwd;
(make install; ./configure ;make -j8 ;make install) > /dev/zero
cd $maxpath
tar xjvf samtools-1.8.tar.bz2 > /dev/zero
yum -y install bzip2-devel > /dev/zero
#(make clean && ./configure --enable-plugins --enable-libcurla --prefix=${maxpath}/samtools-1.8  && make all all-htslib  && make install install-htslib) > /dev/zero
(cd ${maxpath}/samtools-1.8; autoheader;autoconf -Wno-syntax;./configure --prefix=${maxpath}/samtools-1.8; make -j 8; make install) > /dev/zero
[[ -f ${maxpath}/Bubalus01.rmdup.bam ]] || rsync -avP /sources/benchmark/cpu/samtools/data/bam/Bubalus01.rmdup.bam $maxpath > /dev/zero
samtoolsbin=${maxpath}/samtools-1.8/samtools
echo --------running samtools in single socket---------
(time numactl -N 0 -m 0 $samtoolsbin sort -@ $(($NOHTN/$((NUMANUM+1))))  ${maxpath}/Bubalus01.rmdup.bam > /dev/zero) 2>/tmp/samtools.log
#rm -rf ${maxpath}/Bubalus01.rmdup.bam ${maxpath}/samtools*
}

CD-HIT()
{
echo "-------------install-cd-hit---------------"
checktemppath 24565756
cdhitname="cd-hit-v4.6.8-2017-1208"
rsync -avP /sources/benchmark/cpu/cd-hit/${cdhitname}-source.tar.gz $maxpath > /dev/zero
cd $maxpath
tar xzf ${cdhitname}-source.tar.gz  > /dev/zero
cd ${cdhitname}
make clean
make openmp=yes > /dev/zero
chmod 755 /${maxpath}/${cdhitname}/cd-hit-est
cdhit_file=longest_orfs.cds.top_longest_5000
cd $maxpath
[[ ! -f ${maxpath}"/"${cdhit_file} ]] && rsync -avP /sources/benchmark/cpu/cd-hit/data/$cdhit_file $maxpath > /dev/zero
echo "run cd-hit..."
echo "time numactl -m 0 -N 0 ${maxpath}/${cdhitname}/cd-hit-est -i ${maxpath}/${cdhit_file} -o test -c 0.8 -M $mem40_MB -T $(($NOHTN/$((NUMANUM+1))))"
echo --------running cd-hit in single socket---------
(time numactl -m 0 -N 0 ${maxpath}/${cdhitname}/cd-hit-est -i ${maxpath}"/"${cdhit_file} -o test -c 0.8 -M $mem40_MB -T $(($NOHTN/$((NUMANUM+1)))) >/dev/zero) 2>/tmp/cd-hit.log
#rm -f ${maxpath}"/"$cdhit_file ${maxpath}/test
}

MEGAHIT()
{
checktemppath 54565756
megahit_file1=k67.bubble_seq.fa
megahit_file2=k67.contigs.fa
megahit_file3=reads.lib.bin
temppath=$maxpath
[[ ! -d $temppath ]] && mkdir $temppath
cd $temppath
[[ ! -f $temppath"/"$megahit_file1 ]] && rsync -avP /sources/benchmark/cpu/megahit/$megahit_file1 $temppath > /dev/zero
[[ ! -f $temppath"/"$megahit_file2 ]] && rsync -avP /sources/benchmark/cpu/megahit/$megahit_file2 $temppath > /dev/zero
[[ ! -f $temppath"/"$megahit_file3 ]] && rsync -avP /sources/benchmark/cpu/megahit/$megahit_file3 $temppath > /dev/zero
echo /sources/benchmark/cpu/megahit/megahit_v1.1.3_LINUX_CPUONLY_x86_64-bin/megahit_asm_core iterate -c ${temppath}/${megahit_file2} -b ${temppath}/${megahit_file1} -k 67  -s 10 -t $NCPU -o $temppath -r ${temppath}/${megahit_file3} -f binary
echo ----------running megahit all cores-------------
(time /sources/benchmark/cpu/megahit/megahit_v1.1.3_LINUX_CPUONLY_x86_64-bin/megahit_asm_core iterate -c ${temppath}/${megahit_file2} -b ${temppath}/${megahit_file1} -k 67  -s 10 -t $NCPU -o $temppath -r ${temppath}/${megahit_file3} -f binary >/dev/zero) 2>/tmp/megahit.log
#echo ----------numa0------------
#[[ ! -z $NUMANUM ]] && echo only single node,exit numa test || (time numactl -m 0 -N 0 /sources/benchmark/cpu/megahit/megahit_v1.1.3_LINUX_CPUONLY_x86_64-bin/megahit_asm_core iterate -c ${temppath}/${megahit_file2} -b ${temppath}/${megahit_file1} -k 67  -s 10 -t $(($NOHTN/$((NUMANUM+1)))) -o $temppath -r ${temppath}/${megahit_file3} -f binary > /dev/zero )
#rm -f ${maxpath}/${megahit_file1} ${maxpath}/${megahit_file2} ${maxpath}/${megahit_file3}
}


MECAT2PW()
{
checktemppath 514565756
echo "-------------mecat2pw install---------------"
cd /sources/benchmark/cpu/MECAT/MECAT; make clean ;
cd $maxpath
mecat2pwfile=all.subreads-2.fasta
rsync -avP /sources/benchmark/cpu/MECAT/MECAT $maxpath > /dev/zero
cd ${maxpath}/MECAT; make clean; make -j 8 > /dev/zero
[[ ! -f ${maxpath}"/"${mecat2pwfile}.gz ]] && rsync -avP /sources/benchmark/cpu/MECAT/${mecat2pwfile}.bz2 $maxpath  > /dev/zero
cd $maxpath; [[ -f all.subreads.fasta ]] || pbzip2 -d -f ${mecat2pwfile}.bz2 > /dev/zero
echo "-------------mecat2pw all cores---------------"
(time ${maxpath}/MECAT/Linux-amd64/bin/mecat2pw -j 0 -d ${maxpath}/${mecat2pwfile} -o ${maxpath}/${mecat2pwfile} -w ${maxpath}/mecat_reslut -t $NCPU > /dev/zero) 2>/tmp/mecat2pw.log
#echo -----------node0---------------
#[[ ! -z $NUMANUM ]] && echo only single node,exit numa test || (time numactl -m 0 -N 0 ${maxpath}/MECAT/Linux-amd64/bin/mecat2pw -j 0 -d ${maxpath}/${mecat2pwfile} -o ${maxpath}/${mecat2pwfile} -w ${maxpath}/mecat_reslut -t $(($NOHTN/$((NUMANUM+1)))) >/dev/zero )
#rm -rf ${maxpath}/${mecat2pwfile} ${maxpath}/MECAT
}


MINIMAP2()
{
checktemppath 514565756
[[ ! -d ${maxpath} ]] && mkdir -p ${maxpath}
echo "-------------minimap2 install---------------"
rsync -avP /sources/benchmark/cpu/minimap2 $maxpath > /dev/zero
cd ${maxpath}/minimap2; make clean ; make -j 8 > /dev/zero
cd $maxpath
[[ ! -f ${maxpath}/Nanopore.fastq.gz ]] && rsync -avP /sources/benchmark/cpu/minimap2/test_data/Nanopore.fastq.gz $maxpath
echo "-------------running minimap2 all cores---------------"
(time ${maxpath}/minimap2/minimap2 ${maxpath}/Nanopore.fastq.gz ${maxpath}/Nanopore.fastq.gz -ax splice -k14 -uf -t $NCPU >/dev/zero) 2>/tmp/minimap2.log
#echo ---minimap2 node0------------
#[[ -z $NUMANUM  ]] && echo only single node,exit numa test || (time numactl -m 0 -N 0 ${maxpath}/minimap2/minimap2 ${maxpath}/Nanopore.fastq.gz ${maxpath}/Nanopore.fastq.gz -ax splice -k14 -uf -t $(($NOHTN/$((NUMANUM+1)))))
#rm -f ${maxpath}/*gz
}

GCC()
{
temppath=/dev/shm
tmpfree=$(df -h $temppath | awk -F'[ G]+' '$0~/\// {print $(NF-2)}')
[[ $tmpfree -lt 5 ]] && echo "no enough capacity in ${temppath}" && return 0
cd $temppath ; pwd
[[ ! -f ${temppath}/gcc-5.5.0.tar.xz ]] && rsync -avP /sources/benchmark/src/gcc-5.5.0.tar.xz $temppath
yum install -y gmp-devel mpfr-devel libmpc-devel
tar xJvf gcc-5.5.0.tar.xz > /dev/zero
cd /${temppath}/gcc-5.5.0
make clean > /dev/zero
./configure --disable-multilib  --enable-languages=c,c++ --enable-libstdcxx-threads  --enable-libstdcxx-time  --enable-shared  --enable-__cxa_atexit  --disable-libunwind-exceptions --disable-libada  --host x86_64-redhat-linux-gnu  --build x86_64-redhat-linux-gnu  --with-default-libstdcxx-abi=gcc4-compatible > /dev/zero
echo ------running gcc all cores------
(time make -j $NCPU >/dev/zero) 2>/tmp/gcc.log
}

INITDATA()
{
yum -y groupinstall "Development Tools" 2 > $DEVZERO
#checkstatus
yum -y install gcc-c++ p7zip sysbench make gcc zlib-devel ncurses-devel numactl gcc-gfortran pigz pbzip2 2 > $DEVZERO
#checkstatus

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
#make target=UNIX  CC=gcc CXX=g++ opt='-DTEST -DINLINEASM -DPOPCNT -DCPUS=$NCPU'  CFLAGS='-Wall -pipe -O3 -fprofile-arcs -pthread'  CXFLAGS='-Wall -pipe -O3 -fprofile-arcs -pthread'  LDFLAGS=' -lstdc++ -fprofile-arcs -pthread -lstdc++ ' crafty-make > $DEVZERO

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
#SYSBENCH
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
		main 2>&1 | tee /tmp/cpu-bench.log
		;;
	-h)
		usage
		;;
	-help)
		usage
		;;
	*)
		#main | awk --posix '$NF~/[0-9]{2}/' | tee /tmp/cpu-bench
		main | tee /dev/shm/cpu-bench.log
                usage
		;;
esac

swapon -a
