#!/bin/bash
####################################################
#title           :addHostFromLeases.sh
#description     :This script is used to add hosts from the lease file to dhcp.conf
#author          :Brandon Smitley
#date            :Last updated October 23, 2017
#version         :0.2
####################################################
#Set your lease file
leases=dhcpleases

#Set a place to set dhcp leases after they have been parsed 
dhcpparsed=dhcpparsed

#Set your dhcp.conf
dhcpconf=dhcp_conf

#Set your dhcp copy
dhcpcopy=dhcp_copy

#Set lock file variable
lf=/var/lock/addHostFromLeases.lock


#if lock file exists exit
[ -f $lf ] && echo "Lock file exists" && exit 1

#creat lock file
touch $lf


#Split the information out of the lease list
awk 'BEGIN{
    while( (getline line < "leaselist") > 0){
        lease[line]
	}
    RS="}"
    FS="\n"
}
/lease/{

    for(i=1;i<=NF;i++){
        gsub(";","",$i)
        if ($i ~ /lease/) {
            m=split($i, IP," ")
            ip=IP[2]
        }
        if( $i ~ /hardware/ ){
            m=split($i, hw," ")
            mac=hw[3]
        }
	#Dont need the hostname
#	if ( $i ~ /client-hostname/){
#             m=split($i,ch, " ")
#             hostname=ch[2]
#      }

    }

# print ip ","hostname","mac 
  print ip ","mac
	
} ' $leases > $dhcpparsed


#Make a copy of DHCP conf to right to the orginal
cp -p $dhcpconf $dhcpcopy

#See if the mac exists in dhcp.conf
while IFS=, read ip mac;do

if grep -q  $mac $dhcpcopy; then
	echo true
else
	nscheck=`nslookup  $ip  | grep -i name | awk '{print $4}' | head -1 | sed 's/.$//' | tr '[:upper:]' '[:lower:]'`
	echo  $mac
cat <<EOT >> $dhcpcopy 

host $nscheck {
   option host-name "$nscheck";
   hardware ethernet $mac;
   fixed-address $ip;
}

EOT
	
fi

done < $dhcpparsed

#Check to see if there is a change in dhcp config
cmp -s test2 test1
if [ "$?" != "0" ]; then

today="$( date +"%Y%m%d-%H%M" )"

#if there is a change get the date and time and make a backup
bkp="dhcpd.conf-$today.bkp"

mv $dhcpconf $bkp 

#Keep 10 backups and remove the oldest one from there.
ls -t *.bkp | sed  '1,10d'| xargs -d '\n' rm

#Create the new DHCP conf
mv $dhcpcopy $dhcpconf
fi

#rndc reload

#delete the lock and temp files
rm $lf
rm $dhcpparsed

