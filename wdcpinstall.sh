#!/bin/bash 

if [ $# != 1 ] ; then 
echo "USAGE: $0 {command}" 
echo " e.g.: $0 install" 
exit 1; 
fi
if [ $UID != 0 ]; then
    echo "You must be root to run the install script."
    exit 1;
fi
DEFAULTE_DATADISK=/data
MIRRORS=mirrors.tencentyun.com
checkyum()
{
	ping=`ping -c 1 $MIRRORS|grep loss|awk '{print $6}'|awk -F "%" '{print $1}'`
	if [ $ping -eq 100  ];then
		echo ping $MIRRORS fail
        	echo please checkyour network config
		exit 1; 
	fi
	cd /tmp && wget -q http://mirrors.tencentyun.com/install/softinst.sh && chmod +x softinst.sh && ./softinst.sh
	return 0
}


check_virtualplatform()
{
  # check which OS and ver
  if [ -d /proc/xen/ ];then
    echo xen
  elif [ `ethtool -i eth0|grep virtio_net|wc -l` -gt 0 ]||[ `lsmod|grep virtio|wc -l` -gt 0 ]||[ -d /sys/module/virtio_net/ ];then
    echo kvm
  else
    echo unknown virtualplatform
    exit 1;
  fi
  return 0
}
check_datadisk()
{
	vp=`check_virtualplatform`
	if [ $vp = 'xen' ];then
		#echo xen
		DATADEV=/dev/xvdb
		SWAPDEV=/dev/xvdc
	elif [ $vp = "kvm" ];then
		#echo kvm
		DATADEV=/dev/vdb
		SWAPDEV=/dev/vdc
	else
		printf "unknownplatform\n"
		exit 1;
	fi
	if [ `fdisk -l 2>  /dev/null|grep $SWAPDEV|wc -l` -gt 0 ];then
	#if [ `fdisk -l 2>  /dev/null|grep $DATADEV|wc -l` -gt 0 ];then
		#echo DataDisk is $DATADEV
		if [ `fdisk -l 2>  /dev/null|grep "$DATADEV[0-9]."|wc -l` -eq 0 ]&&[ `blkid |grep swap|grep $DATADEV|wc -l` -eq 0 ];then
			printf "your datadisk %s need to be formated and mounted\n" $DATADEV
			#format and mount
			while true;do
				read -p "auto format and mount?(Yes/No)" x
				case $x in
					yes|Yes|YES|Y|y)
						format_disk $DATADEV
						if [ $? -ne 0 ];then
							printf "format failed\n"
							exit 1;
						fi
						printf "format and mount success\n"
						printf "install path /data\n"
						return 0;;
					no|No|NO|n|N)
						 exit 1;;
					*);;
				esac
			done
			#install_wdcp /data
		elif [ `fdisk -l 2>  /dev/null|grep "$DATADEV[0-9]."|wc -l` -gt 0 ]&&[ `blkid |grep swap|grep $DATADEV|wc -l` -eq 0 ];then
			#echo "already mounted"
			if [ `df -h|grep $DATADEV[0-9].|wc -l` -gt 0 ];then
				MAXSPACE=`df -h|grep $DATADEV[0-9]. |awk '{print $5|"sort"}'|head -n1`
				#echo $MAXSPACE
				DATAPART=`df -h|grep $DATADEV[0-9]. |grep $MAXSPACE|awk '{print $6}'|head -n1`
				#install_wdcp $DATAPART
				printf "install path %s\n" $DATAPART
				#echo $DATAPART
				DEFAULTE_DATADISK=$DATAPART
				return 0
				#printf "test"
			else
				printf "your datadiskpart `fdisk -l 2>  /dev/null|grep "$DATADEV[0-9]."|awk '{print $1}'` need to be mounted\n"
				exit 1;
			fi
		else
			printf "please check yourdatadisk\n" 
			exit 1;
		fi
	else
		mkdir -p /data
		#install_wdcp /data
		printf "install path /data\n"
		return 0
	fi
}

install_wdcp()
{
	if [ $# != 1 ] ; then 
		echo "USAGE: $0 {directory}" 
		echo " e.g.: $0 /data" 
		exit 1; 
	fi
	DATAPART=$1
	cd $DATAPART
	if [ -d /www ];then
		printf "please remove your /www directory\n"
		exit 1;
	fi
	if [ -d $DATAPART/www ];then
		printf "please remove your $DATAPART/www directory\n"
		exit 1;
	fi
	mkdir $DATAPART/www
	ln -s $DATAPART/www /www
	wget http://dl.wdlinux.cn:5180/lanmp_laster.tar.gz
	if [ $? -ne 0 ];then
		printf "download wdcp failed\n"
		exit 1;
	fi
	tar zxvf lanmp_laster.tar.gz
	sh install.sh
}
format_disk()
{
	if [ $# != 1 ] ; then 
                echo "USAGE: $0 {directory}" 
                echo " e.g.: $0 /data" 
                exit 1; 
        fi
        DISK=$1
	if [ -d /data ]&&[ `ls -al /data|egrep -v "^*\ .$|^*\ ..$|^*\ lost\+found$"|wc -l` -gt 0 ];then
		printf "your /data is in use\n"
		exit 1;
	fi
	echo -e "n\np\n1\n\n\nw\n"|fdisk $DISK &> /dev/null 
	mkfs.ext4 $DISK"1"
	if [ $? -ne 0 ];then
		printf "format failed\n"
		exit 1;
	fi
	mkdir -p /data
	mount $DISK"1" /data
	if [ $? -ne 0 ];then
		printf "mount failed\n"
		exit 1;
	fi
	echo -e $DISK"1""           /data                ext4       defaults 0 0" >> /etc/fstab
	return 0;
}
#result=`check_datadisk`
#echo $result

#echo $vp
if [ $1 = "install" ];then
	check_datadisk
	if [ $? -ne 0 ];then
		printf "check disk failed\n"
		exit 1;
	else
		printf "install in %s\n" $DEFAULTE_DATADISK
	fi
fi
