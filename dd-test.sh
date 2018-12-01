#!/bin/bash
## check sha1sum for each files
## 20181201 because https://jira.whamcloud.com/browse/LU-11663, add drop cache in this test

[[ -z $1 ]] && echo "Please input test filename." $0 " filename" && dd if=/dev/urandom of=X8dmobGzRQ bs=1M count=1024
[[ -n fn ]] && fn=$1 || fs=X8dmobGzRQ

count=1000
countH=0
sname="Bytes.sha1"
dropcname="Bytes.drop.sha1"
lname="Bytes.pre.sha1"
hashlog="bad_hash"
[[ -f $hashlog ]] && rm -f $hashlog
[[ -f $sname ]] && rm -f $sname
[[ -f $lname ]] && rm -f $lname
ls | grep xQRj7YkDNp0Bytes && rm -f *xQRj7YkDNp0Bytes

function finish {
[[ -f $sname ]] && rm -f $sname
[[ -f $lname ]] && rm -f $lname
ls | grep xQRj7YkDNp0Bytes && rm -f *xQRj7YkDNp0Bytes
break 2
}

trap finish HUP INT QUIT TERM EXIT

looptiny() {
	fn=$1
        flag=$2
	for i in {1,4,63,64,127,128,511,512,1111,1024,4096,4099,5000}
	do
		ofname=$fn"_"$i"xQRj7YkDNp0Bytes"
		[[ $flag != "direct"* ]] && [[ $flag != "sync"* ]] && dd if=$fn of=$ofname obs=1 ibs=1 count=$i
		[[ $flag == "direct"* ]] && dd if=$fn of=$ofname obs=1 ibs=1  count=$i oflag=direct iflag=direct
		[[ $flag == "sync"* ]] && dd if=$fn of=$ofname obs=1 ibs=1  count=$i oflag=sync iflag=sync
	done
	sha1sum *xQRj7YkDNp0Bytes > $sname
	echo 3 > /proc/sys/vm/drop_caches
	sha1sum *xQRj7YkDNp0Bytes > $dropcname
	diff $sname $dropcname >> $hashlog || date >> $hashlog
        [[ ! -f $lname ]] && mv $sname $lname
	ls | grep xQRj7YkDNp && rm -f *xQRj7YkDNp0Bytes
	[[ -f $lname ]] && diff $sname $lname >> $hashlog || date >> $hashlog
}

while :
do
	looptiny $fn aio
	looptiny $fn direct
	looptiny $fn sync
	((count--))

	if [[ $count -le 0 ]]
	then
		dd if=$fn of=$fn"_bak" bs=1M conv=sparse
		sha1sum $fn $fn"_bak" >> $fn".whole.sha1"
		echo 3 > /proc/sys/vm/drop_caches
	        sha1sum $fn $fn"_bak" >> $fn".whole.dropc.sha1"
	        diff $fn".whole.sha1" $fn".whole.dropc.sha1"   >> $hashlog || date >> $hashlog
		rm -f $fn"_bak"
		export count=1000 && ((countH++)) && echo $countH > counts
	fi
done
