#!/bin/bash -

#title				:quicktest.sh
#description			:Bicomsystems automatic SERVERware Quick self test v1.0
#author			:Damir Smigalovic
#sw-version			:3.2
#usage				:sh quicktest.sh
#Created by 		:SERVERware Team

export GREEN='\033[0;32m'
export RED='\033[0;31m'
export NC='\033[0m'

echo -e "${GREEN}
   ____        _      __      ______	   __   ______          __
  / __ \__  __(_)____/ /__   / ___| |     / /  /_  __/__  _____/ /_
 / / / / / / / / ___/ //_/   \__ \| | /| / /    / / / _ \/ ___/ __/
/ /_/ / /_/ / / /__/ ,<     ___/ /| |/ |/ /    / / /  __(__  / /_
\___\_\__,_/_/\___/_/|_|   /____/ |__/|__/    /_/  \___/____/\__/ ${NC}"

echo -e "\n -------------------------- \n"
echo -e "${GREEN}Bicomsystems Quick SERVERware self test v1.0${NC}"
echo -e "\n"
date
echo -e "\n"
echo -e "${GREEN}SERVERware services VERSION: ${NC}"
echo -e "\n"
echo -e "SERVERware: $(cat /etc/serverware.version)"
echo -e -n "sw-connector: "
$(sw-connector --version)
echo -e "lxc: $(lxc-ls --version)"
echo -e -n "$(sipprot version)"
echo -e "bssup: $(bssup --version)"
echo -e "$(swrepl -version)"
echo -e "$(zfs version)"
echo -e "$(uname -a)"
echo -e "\n"
echo -e "\n"
echo -e "${RED}THE CURRENT NEIGHBOUR TABLE: \n${NC}$(ip neigh)"
echo -e "\n"
echo -e "\n -------------------------- \n"

if [ $HOSTNAME == "CONTROLLER" ]; then

	echo -e "sw-connector"
	/etc/init.d/sw-connector status
	echo -e "syslog-ng"
	/etc/init.d/syslog-ng status
	echo -e "sw-wcp"
	/etc/init.d/sw-wcp status
	echo -e "sw-mgr"
	/etc/init.d/sw-mgr status
	echo -e "bssupd"
	/etc/init.d/bssupd status
	echo -e "\n -------------------------- \n"
	echo -e "Stuc VPSs in REMOVED section:"
	mysql serverware -e "SELECT * FROM sw_vpses WHERE name LIKE '%@%@%' AND state='REMOVED';"
	echo -e "\n"
	echo -e "\n -------------------------- \n"
	echo -e "${RED}syslog last 100 lines ERROR, WARNING message${NC}"
	tail -n100 /var/log/messages | grep --color=always -i 'ERROR\|WARNING'

else
	echo -e "${RED}CONTROLLER${NC}"
	/etc/init.d/controller status
	echo -e "\n"
	echo -e "${RED}SERVERware ROLE${NC}"
	echo -e "\n"
	/etc/init.d/sysmonit status
	sysmonit -S
	echo -e "\n"
	echo -e "${RED}sw.conf: \n\n${NC}$(cat /etc/serverware/sw.conf)"
	echo -e "\n"
	echo -e "\n -------------------------- \n"
	echo -e "${RED}VIRTUAL NETWORK INTERFACES${NC}"
	echo -e "\n"
	cat /etc/conf.d/prerq.net.* | grep -B 1 --color=always "slaves\|rc_net\|mode\|miimon"
	echo -e "\n -------------------------- \n"
	echo -e "${RED}NETWORK INTERFACES STATUS UP-DOWN ${NC}"
	echo -e "\n"
	ifconfig | grep -A 2 --color=always 'UP\|DOWDN'
	echo -e "\n -------------------------- \n"
	echo -e "${RED}INTERFACES STATUS FROM KERNEL${NC}"
	echo -e "\n"
	ifstat -a
	echo -e "\n -------------------------- \n"
	echo -e "${RED}DNS CONFIGURATION${NC}"
	echo -e "\n"
	cat /etc/resolv.conf
	echo -e "\n -------------------------- \n"
	echo -e "${RED}SERVICES Running${NC}"
	echo -e "\n"
	echo -e "sw-connector"
	/etc/init.d/sw-connector status
	echo -e "syslog-ng"
	/etc/init.d/syslog-ng status
	echo -e "bssupd"
	/etc/init.d/bssupd status
	echo -e "swcentlog"
	/etc/init.d/swcentlogd status
	echo -e "swhspared"
	/etc/init.d/swhspared status
	echo -e "swrepl - must be enabled on license"
	/etc/init.d/swrepl status
	echo -e "sipprotd - must be enabled on license"
	/etc/init.d/sipprotd status
	echo -e "\n sipprotd - Blacklisted IPS \n"
	cat /opt/sipprot/conf/sipprot.blacklist

	echo -e "\n -------------------------- \n"
	echo -e "${RED}IO - WAIT ${NC}"
	echo -e "\n"
	iostat -c | awk '/^ /{print $4}'
	echo -e "\n -------------------------- \n"
	echo -e "${RED}MEMORY ${NC}"
	echo -e "\n"
	free -mh
	echo -e "\n -------------------------- \n"
	echo -e "${RED}DISK USAGE${NC}"
	echo -e "\n"
	df -h
	echo -e "\n -------------------------- \n"
	echo -e "${RED}ISCSI nodes${NC}"
	echo -e "\n"
	iscsiadm -m session
	echo -e "\n -------------------------- \n"
	echo -e "${RED}MIRROR CONFIGURATION FILE${NC}"
	echo -e "\n"
	cat /etc/sysmonit/mirror.cfg
	echo -e "\n -------------------------- \n"
	echo -e "${RED}ZPOOL STATUS for NETSTOR${NC}"
	echo -e "\n"
	zpool status NETSTOR || true
	echo -e "\n -------------------------- \n"
	echo -e "${RED}ZFS LIST OF DATASETS: name,volsize,used,usedbydataset,usedbysnapshots,origin ${NC}"
	echo -e "\n"
	zfs list -r -Ho name,volsize,used,usedbydataset,usedbysnapshots,origin
	echo -e "\n -------------------------- \n"
	echo -e "${RED}syslog last 100 lines ERROR, WARNING, message${NC}"
	echo -e "\n"
	tail -n100 /var/log/messages | grep --color=always -i 'ERROR\|WARNING'
fi
