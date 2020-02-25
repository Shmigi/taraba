#!/bin/bash
date
# Define colors
C_RED="\e[1;31m"
C_GREEN="\e[1;32m"
C_BLUE="\e[1;34m"
C_END="\e[0m"

#define empty var for yes no input
YN=""
# this function checks for imput Y, N, and Q
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
#define empty var host address user input
ADDR=""
# this function listen for input of hostname or address, check open port and writes local public key to remote allowed keys
host_check() {
	while true; do
		echo -e -n "\n${C_GREEN} Please enter the ip address of Standalone PBXware: ${C_END}" #user input address
		read ADDR
		echo ""
		if timeout 1 bash -c "echo >/dev/tcp/$ADDR/2020" >/dev/null 2>&1; then #check for server validation ping port 2020 timeout is for hosts with slow response
			echo -e "${C_GREEN} Host $ADDR OK${C_END}\n"
			ssh-copy-id -o StrictHostKeyChecking=no -p2020 -i ~/.ssh/id_rsa.pub root@$ADDR &>/dev/null #copy key for further use
			return 1
		else
			echo -e "${C_RED} Host not reacheable: $ADDR ${C_END}\n"
			echo -e "${C_RED} There was problem accessing $ADDR please check your input and try again${C_END}\n\n"
		fi
	done
}

SOURCEDIR="/opt/" #define empty var for local vps name user input
DESTDIR=""        #define empty var remote vps name  user input
# this function listen for input of hostname or address, check open port and writes local public key to remote allowed keys
vps_check() {

	while true; do
		echo -e -n "${C_GREEN} Name of local VPS where to copy ( VPS must be stopped ): ${C_END}"
		read DESTDIR
		echo ""
		vps_exist() {
			if [ $1 = "remote" ]; then
				exist=$(lxc-info -s -n $DESTDIR 2>/dev/null | grep "STOPPED") # list local stopped vps names and search for vps name
			fi
			if [ -n "$exist" ]; then
				return 0
			else
				return 1
			fi
		}
		# if fail to locate VPS report error
		vps_exist "remote"
		if [ $? -ne 0 ]; then
			echo -e -n "\n${C_RED} Error: Local VPS does not exist or running!!! ${C_END}\n" >&2
			continue
		fi
		break
	done
}
# user interaction
echo ""
echo -e "${C_GREEN} Hello, $USER. This is Automated migration script ${C_END}"
echo ""
echo -e "${C_GREEN} This script should be used only to migrate Standalone PBXware to SERVERware 3 VPS ${C_END}"
echo ""

host_check
vps_check

# display input informations
yesno_input " MOVE VPS FROM HOST:  ${C_BLUE}$ADDR${C_END}   DIR:  ${C_GREEN}$SOURCEDIR${C_END}   TO SERVERware 3 VPS NAME:  ${C_RED}$DESTDIR${C_END} \n "

if [ "$?" == "0" ]; then
	# Connect to remote and rsync folders, display output in one line
	rsync -azvPh --progress --inplace --delete -e "ssh -p 2020" root@$ADDR:/opt/ /home/lxc/$DESTDIR/rootfs/opt/ 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	rsync -azvPh --progress --links --inplace --delete -e "ssh -p 2020" root@$ADDR:/etc/localtime /home/lxc/$DESTDIR/rootfs/etc/localtime 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	rsync -azvPh --progress --inplace --delete -e "ssh -p 2020" root@$ADDR:/etc/ssh/ /home/lxc/$DESTDIR/rootfs/etc/ssh/ 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	rsync -azvPh --progress --inplace --delete -e "ssh -p 2020" root@$ADDR:/root/.ssh/ /home/lxc/$DESTDIR/rootfs/root/.ssh/ 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	# Connect to remote and copy root password
	RPWD=$(ssh root@$ADDR -p2020 cat /etc/shadow | grep -E "^root")
	# open local file and replace root password with password from remote
	sed -i 's,'"^root:.*"','"$RPWD"',g' /home/lxc/$DESTDIR/rootfs/etc/shadow
	echo ""
	echo -e "\n${C_GREEN} Done, please run again for another VPS!\n${C_END} "
else
	echo ""
	echo -e "\n${C_RED} Error nothing changed!. Please check input and try again\n${C_END} "
fi
