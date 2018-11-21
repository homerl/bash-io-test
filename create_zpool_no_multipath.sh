#!/bin/bash
###########################################################################
# Usage:        $0
# Discription:  In no-multipath env, generate zpool create script, the script could divide SAS dev by SAS expander
###########################################################################

usage() {
        echo "Usage: $0 [-n raidz dev number,default 15] [-l raidz level,default raidz3] [-a raidz ashift size,default 9] [-o ost index number,default 0] [-c set compress mode,default lz4] [-m zfsmount on or off, default on] [-j jbod dev number]" 1>&2; exit 1;
}

while getopts ":n:l:a:o:c:m:j:" z; do
    case "${z}" in
        n)
            raidznum=${OPTARG};
            ;;
        l)
            raidzlv=${OPTARG};
            ;;
        a)
            ashift=${OPTARG};
            ;;
        o)
            ost_index=${OPTARG};
            ;;
        c)
            zfscom=${OPTARG};
            ;;
        m)
            zfsmount=${OPTARG};
            ;;
        j)
            jbodevnum=${OPTARG};
            ;;
        *)
            usage
            ;;
    esac
done
tempdir="/tmp/a76ea6ac"
[[ -f /etc/hostid ]] || genhostid
([[ -n $raidznum ]] && [[ "$raidznum" =~ ^[0-9]+$ ]]) || export raidznum=15; echo $raidznum
[[ -n $raidzlv ]] || export raidzlv="raidz3" ;echo $raidzlv
([[ -n $ashift ]] && [[ "$ashift" =~ ^[0-9]+$ ]]) || export ashift=9;
([[ -n $ost_index ]] && [[ "$ost_index" =~ ^[0-9]+$ ]]) || export ost_index=0
[[ -n $zfscom ]] || export zfscom="lz4"
[[ -n $zfsmount ]] || export zfsmount="on"
[[ ! -d $tempdir ]]  || rm -rf $tempdir
[[ ! -d $tempdir ]]  && mkdir -p $tempdir
[[ -z $jbodevnum ]] && [[ "$ost_index" =~ ^[0-9]+$ ]] && echo "please input jbod dev num, $0 -j 84 or -j 60" && exit 1

#echo $tempdir  && pwd
cd $tempdir
lsscsi -tiv  | sed -z 's/\n  dir:/ /g' | awk -v tempdir="$tempdir" -F '[:\\[/ ]+' '$10!~/-/ && $0~/disk/ && $7~/sas/ {print "/dev/disk/by-id/scsi-"$11,$2 > tempdir"/"$30"_"$31"_"$32"_"$33"_"$34}'

for i in $(ls)
do
   hsname=""
   devnum=$(wc -l $i | awk '{print $1}')
   hsnum=$(($devnum%$raidznum))

   ## check each HBA connect number% jbod dev num == 0 ? when the result large than 0 that means there is some slots is empty
   slotchk=$(($devnum%$jbodevnum))
   echo "devnum:"$devnum" jbodevnum:"$jbodevnum
   if [[ $slotchk -gt 0 ]]
   then
       echo "Found empty slot in JBOD; slot check:"$slotchk
       exit 1
   fi

   [[ $hsnum -gt 0 ]] && hsname=$(awk -v devnum=$devnum -v hsnum=$hsnum 'BEGIN{ORS=" "} BEGIN{printf " spare "}{if(NR>(devnum-hsnum)) print $1}' $i)

   echo "hsnum:"$hsnum" raidlv:"$raidzlv

   if [[ $hsnum -eq 0 ]] && [[ $raidzlv == *"raidz3"* ]]
   then
      echo "Raidz3 don 't need hot spare, hotspare num:"$hsnum
   else
      echo "Not found hotspare, hotspare num:"$hsnum
   fi

   if [[ $devnum -gt 4 ]]
   then
      echo "#"$(wc -l $i | awk '{print $1}') " Begin to create raidz"

      awk -v zfsmount="$zfsmount" -v zfscom="$zfscom" -v raidznum="$raidznum" -v hsname="$hsname" -v devnum="$devnum" -v hsnum="$hsnum" -v ost_index=$ost_index -v raidzlv="$raidzlv" -v ashiftvar="$ashift" '{
  if(NR<=(devnum-hsnum)) {
    if(NR%raidznum==1) {
      printf "zpool create ost_"ost_index " -O canmount="zfsmount" -O xattr=sa -O acltype=posixacl -o cachefile=none -O compression="zfscom" -o ashift="ashiftvar" "raidzlv" "$1" ";
      ost_index++
    } else if(NR%raidznum==0) {
      print $1" "hsname;
    } else if(NR==(devnum-hsnum)) {
      print " "hsname;
    } else {
      printf $1" ";
    }
  }
} END{ exit ost_index }' $i
   ost_index=$?
   else
      echo "#"$(wc -l $i | awk '{print $1}')" number not enough"
   fi
done
