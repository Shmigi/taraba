#!/bin/bash

# Define colors
C_RED="\e[1;31m"
C_GREEN="\e[1;32m"
C_YELLOW="\e[1;33m"
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

SRCDIR=""
SRC_RUNNING=0
check_remote_vps() {
	while true; do
		echo -e -n "\n Please enter the name of the source VPS you want to migrate from the remote SERVERware 3 host: "
		read SRCDIR
		echo ""

		# check if vps exists on the remote host
		ssh -p 2222 root@$ADDR lxc-info -s -n $SRCDIR &>/dev/null
		if [ $? -ne 0 ]; then
			echo -e -n "\n${C_RED} Error: Remote VPS does not exist!!!${C_END}\n" >&2
			continue
		fi

		# check if VPS running
		ssh -p 2222 root@$ADDR lxc-info -s -n $SRCDIR 2>/dev/null | grep "RUNNING" &>/dev/null
		if [ $? -eq 0 ]; then
			echo -e -n "${C_YELLOW} Warning: The source VPS is running!${C_END}\n\n" >&2

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

DESTDIR=""
check_local_vps() {
	while true; do
		echo -e -n "\n Please enter the name of local VPS where to migrate ( VPS must be stopped ): "
		read DESTDIR
		echo ""

		# check if vps exists on the localhost
		lxc-info -s -n $DESTDIR &>/dev/null
		if [ $? -ne 0 ]; then
			echo -e -n "\n${C_RED} Error: Local VPS does not exist!!!${C_END}\n" >&2
			continue
		fi

		lxc-info -s -n $DESTDIR 2>/dev/null | grep "RUNNING" &>/dev/null
		if [ $? -eq 0 ]; then
			echo -e -n "\n${C_RED} Error: Local VPS is running!!!${C_END}\n" >&2
			continue
		fi

		break
	done
}

# user interaction
echo ""
echo -e " Hello, $USER. This is Automated VPS migration script"
echo ""
echo -e "${C_YELLOW} This script should be used only to migrate VPSs between SERVERware 3 clusters ${C_END}"
echo ""

host_check
check_remote_vps
check_local_vps

# display input informations

echo -e " Migrate VPS: ${C_GREEN}$SRCDIR${C_END} from remote HOST: ${C_GREEN}$ADDR${C_END} to local VPS: ${C_RED}$DESTDIR${C_END}\n"

yesno_input " Do you want to proceed?"

if [ "$?" == "0" ]; then
	# Connect to remote and rsync folders, display output in one line
	rsync -azvPh --progress --delete -e "ssh -p 2222" root@$ADDR:/home/lxc/$SRCDIR/rootfs/opt/pbxware/ /home/lxc/$DESTDIR/rootfs/opt/pbxware/ 2>&1 | xargs -L1 printf "\33[2K\r Transferring: %s"
	rsync -azvPh --progress --delete -e "ssh -p 2222" root@$ADDR:/home/lxc/$SRCDIR/rootfs/opt/httpd/ /home/lxc/$DESTDIR/rootfs/opt/httpd/ 2>&1 | xargs -L1 printf "\33[2K\r Transferring: %s"
	rsync -azvPh --progress --delete -e "ssh -p 2222" root@$ADDR:/home/lxc/$SRCDIR/rootfs/home/servers/ /home/lxc/$DESTDIR/rootfs/home/servers/ 2>&1 | xargs -L1 printf "\33[2K\r Transferring: %s"
	# Connect to remote and copy root password
	RPWD=$(ssh root@$ADDR -p2222 cat /home/lxc/$SRCDIR/rootfs/etc/shadow | grep -E "^root")
	# open local file and replace root password with password from remote
	sed -i 's,'"^root:.*"','"$RPWD"',g' /home/lxc/$DESTDIR/rootfs/etc/shadow

	if [ $SRC_RUNNING -eq 1 ]; then
		echo -e "\n\n${C_YELLOW} To ensure data consistency please re-run this script one more time once the source VPS is stopped!${C_END}" >&2
	fi
	echo -e "\n${C_GREEN} Done${C_END}"
else
	echo ""
	echo -e "\n${C_RED} Error!!! Please check input and try again\n${C_END} "
fi
