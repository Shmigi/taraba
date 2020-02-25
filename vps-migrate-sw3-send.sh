#!/bin/bash

#title				:vps-migrate-sw3-send.sh
#description			:Bicomsystems interactive migration script v1.0
#author			:Damir Smigalovic
#sw-version			:3.2
#usage				:sh vps-migrate-sw3-send.sh
#Created by 		:SERVERware Team

date

if [ ${#@} -ne 0 ] && [ "${@#"--help"}" = "" ]; then
		printf -- '\n\nFirst you need to create a VPS on SERVERware3 destination as a placeholder for a VPS we will migrate. \n\n';
		printf -- 'To do this, please navigate to SERVERware 3 GUI Menu ---> VPSs. \n\n';
		printf -- 'Press Create VPS and populate required fields. \n\n';
		printf -- 'Please ensure your new VPS has sufficient storage to accommodate the VPS you are migrating. \n\n';
		printf -- 'Run scrip and follow the steps \n\n';
exit 0;
fi;

	
# Define colors
C_RED="\e[1;31m"
C_GREEN="\e[1;32m"
C_YELLOW="\e[1;33m"
C_BLUE="\e[1;34m"
C_END="\e[0m"

#define empty var for yes no input
YN=""
#this function checks for imput Y, N, and Q
yesno_input() {
			prompt="$1"
			rv=""
			while [ -z "$rv" ]; do
				echo -e -n "${C_BLUE}[*]${C_END} ${prompt} [${C_GREEN}Y${C_END}/${C_RED}N${C_END}] [${C_BLUE}Q${C_END} quit] ? "
				read -n 2 yesno
				rv=$(echo $yesno | grep -P -i "^[ynq]$")
				if [ -z "$rv" ]; then
					echo ""
					echo -e "${C_RED}[!]${C_END} Please answer with ${C_GREEN}Y${C_END}, ${C_RED}N${C_END} or ${C_BLUE}Q${C_END}!\n" >&2
				fi
			done
			echo ""
			YN=$rv
			if [ "$rv" = "q" -o "$rv" = "Q" ]; then
				exit 0
			fi
			if [ "$rv" = "y" -o "$rv" = "Y" ]; then
				rv=0
			else
				rv=1
			fi
			return $rv
}
#define empty var for host address user input
ADDR=""
#this function listen for input of hostname or address, check open port and writes local public key to remote allowed keys
host_check() {
			while true; do
				echo -e -n "\n Please enter the IP address of a remote SERVERware 3 processing host: " #user input address
				read ADDR
				echo ""
				if timeout 1 bash -c "echo >/dev/tcp/$ADDR/2222" >/dev/null 2>&1; then #check for server validation ping port 2222 timeout is for hosts like google.com
					echo -e "${C_GREEN} Host: $ADDR OK${C_END}\n"
					ssh-copy-id -o StrictHostKeyChecking=no -p2222 -i ~/.ssh/id_rsa.pub root@$ADDR &>/dev/null # copy key for further use
					return 1
				else
					echo -e "${C_RED} Host $ADDR is unreachable${C_END}\n"
					echo -e "${C_RED} There was problem accessing $ADDR please check your input and try again${C_END}\n\n"
				fi
			done
}

#Status check for the remote VPS 
SRCDIR=""
SRC_RUNNING=0
check_remote_vps() {
			while true; do
				echo -e -n "\n Please enter the name of the DESTINTION VPS on the remote SERVERware 3 host: "
				read SRCDIR
				echo ""

				#check if vps exists on the remote host
				ssh -p 2222 root@$ADDR lxc-info -s -n $SRCDIR &>/dev/null
				if [ $? -ne 0 ]; then
					echo -e -n "\n${C_RED} Error: Destination VPS does not exist!!!${C_END}\n" >&2
					continue
				fi

				#check if VPS running
				ssh -p 2222 root@$ADDR lxc-info -s -n $SRCDIR 2>/dev/null | grep "RUNNING" &>/dev/null
				if [ $? -eq 0 ]; then
					echo -e -n "${C_YELLOW} Warning: The destination VPS is running!${C_END}\n\n" >&2

					yesno_input " Do you want to proceed anyway?"
					if [ $? -eq 0 ]; then
						SRC_RUNNING=1
						break
					else
						exit 1
					fi

				fi
				break
			done
}

#Status check for the local VPS  
DESTDIR=""
DEST_RUNNING=0
check_local_vps() {
			while true; do
				echo -e -n "\n Please enter the name of LOCAL VPS to migrate ( VPS should be stopped ): "
				read DESTDIR
				echo ""

				#check if vps exists on the localhost
				lxc-info -s -n $DESTDIR &>/dev/null
				if [ $? -ne 0 ]; then
					echo -e -n "\n${C_RED} Error: Local VPS does not exist!!!${C_END}\n" >&2
					continue
				fi

				lxc-info -s -n $DESTDIR 2>/dev/null | grep "RUNNING" &>/dev/null
				if [ $? -eq 0 ]; then
					echo -e -n "\n${C_RED} Error: Local VPS is running!!!${C_END}\n" >&2
	
					yesno_input " Do you want to proceed anyway?"
					if [ $? -eq 0 ]; then
						DEST_RUNNING=1
						break
					else
						exit 1
					fi

				fi
				break
			done
}

#user interaction
echo ""
echo -e " Hello, $USER. This is Automated VPS migration script"
echo ""
echo -e "${C_YELLOW} This script should be used only to migrate VPSs between SERVERware 3 clusters.${C_END}${C_RED}SCRIPT WILL SEND THE VPS TO REMOTE LOCATION!! ${C_END}"
echo ""
echo -e "${C_RED}This script should be run on the host where the source VPS is located ${C_END}"
echo ""

#Run the functions
host_check
check_remote_vps
check_local_vps

#display input informations

echo -e " Migrate local VPS: ${C_GREEN}$DESTDIR${C_END} to remote HOST: ${C_GREEN}$ADDR${C_END} OVER THE VPS: ${C_RED}$SRCDIR${C_END}\n"

yesno_input " Do you want to proceed?"

	#Connect to remote and rsync folders, display output in one line
	rsync -azvPh --progress --delete -e "ssh -p 2222" /home/lxc/$DESTDIR/rootfs/opt/pbxware/ root@$ADDR:/home/lxc/$SRCDIR/rootfs/opt/pbxware/ 2>&1 | xargs -L1 printf "\33[2K\r Transferring: %s"
	rsync -azvPh --progress --delete -e "ssh -p 2222" /home/lxc/$DESTDIR/rootfs/opt/httpd/ root@$ADDR:/home/lxc/$SRCDIR/rootfs/opt/httpd/ 2>&1 | xargs -L1 printf "\33[2K\r Transferring: %s"
	rsync -azvPh --progress --delete -e "ssh -p 2222" /home/lxc/$DESTDIR/rootfs/home/servers/ root@$ADDR:/home/lxc/$SRCDIR/rootfs/home/servers/ 2>&1 | xargs -L1 printf "\33[2K\r Transferring: %s"
	rsync -azvPh --progress --delete -e "ssh -p 2222" /home/lxc/$DESTDIR/rootfs/etc/ssh/ root@$ADDR:/home/lxc/$SRCDIR/rootfs/etc/ssh/ 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	rsync -azvPh --progress --delete -e "ssh -p 2222" /home/lxc/$DESTDIR/rootfs/root/.ssh/ root@$ADDR:/home/lxc/$SRCDIR/rootfs/root/.ssh/ 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	rsync -azvPh --progress --delete -e "ssh -p 2222" /home/lxc/$DESTDIR/rootfs/etc/shadow root@$ADDR:/home/lxc/$SRCDIR/rootfs/etc/shadow 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"	
	
	#Depricated code below 
	#------
	#Copy root password
	#RPWD=$(cat /home/lxc/$DESTDIR/rootfs/etc/shadow | grep -E "^root")
	#paste password to the remote host
	#echo "sed -i 's,'"^root:.*"','"$RPWD"',g' /home/lxc/$SRCDIR/rootfs/etc/shadow" |ssh root@$ADDR -p2222 bash
	#------
	
if [ $SRC_RUNNING -eq 1 ]; then
		echo -e "\n\n${C_YELLOW} To ensure data consistency please re-run this script one more time once the remote VPS is stopped!${C_END}" >&2
	fi
if [ $DEST_RUNNING -eq 1 ]; then
		echo -e "\n\n${C_RED} To ensure data consistency please re-run this script one more time once the source VPS is stopped!${C_END}" >&2
	fi
	echo -e "\n${C_GREEN} Done${C_END}"
else
	echo ""
	echo -e "\n${C_RED} Error!!! Please check input and try again\n${C_END} "
fi