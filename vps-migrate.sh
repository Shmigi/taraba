#!/bin/bash -

#title				:vps-migrate.sh
#description			:Bicomsystems automatic migration script v0.5
#author			:Damir Smigalovic
#sw-version			:all
#usage				:sh vps-migrate.sh

date

# Define colors
C_RED="\e[1;31m"
C_GREEN="\e[1;32m"
C_BLUE="\e[1;34m"
C_END="\e[0m"

# define empty var for yes no input
YN=""
# checks for imput Y, N, and Q
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

# define empty var host address user input

ADDR=""

# this function listen for input of hostname or address, check open port and writes local public key to remote allowed keys

host_check() {
			while true; do
				echo -e -n "\n${C_GREEN} Please enter the ip address of remote SERVERware 1.x: ${C_END}" #user input address
				read ADDR
				echo ""
				if timeout 1 bash -c "echo >/dev/tcp/$ADDR/2222" >/dev/null 2>&1; then #check for server validation ping port 2222 timeout is for hosts with slow response
					echo -e "${C_GREEN} Host $ADDR OK${C_END}\n"
					ssh-copy-id -o StrictHostKeyChecking=no -p2222 -i ~/.ssh/id_rsa.pub root@$ADDR &>/dev/null #copy key for further use
					return 1
				else
					echo -e "${C_RED} Host not reacheable: $ADDR ${C_END}\n"
					echo -e "${C_RED} There was a problem accessing $ADDR please check your input and try again${C_END}\n\n"
				fi
			done
}

# define empty var for local vps name user input

SRCDIR=""
SRC_RUNNING=0

check_remote_vps() {
			while true; do
				echo -e -n "\n ${C_GREEN} Please enter the name of the source VPS you want to migrate from the remote SERVERware host: ${C_END}"
				read SRCDIR
				echo ""

				# check if vps exists on the remote host
				ssh -p 2222 root@$ADDR vps-manage $SRCDIR status 2 &>/dev/null
				ec=$?
				if [ "$ec" != "0" -a "$ec" != "3" ]; then
					echo -e -n "\n${C_RED} Error: The source VPS does not exist!!!${C_END}\n" >&2
					continue
				fi

				# check if VPS running
				ssh -p 2222 root@$ADDR vps-manage $SRCDIR status 2>/dev/nul
				ec=$?
				if [ $ec -eq 0 ]; then
					echo -e -n "${C_YELLOW} Warning: The source VPS is running!${C_END}\n\n" >&2

					yesno_input " Do you want to proceed anyway?"
					if [ $ec -eq 0 ]; then
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
				echo -e -n "\n ${C_GREEN} Please enter the name of local VPS where to migrate ( VPS must be stopped ) ${C_END}: "
				read DESTDIR
				echo ""

				# check if vps exists on the localhost
				lxc-info -s -n $DESTDIR &>/dev/null
				if [ $? -ne 0 ]; then
					echo -e -n "\n${C_RED} Error: Local VPS does not exist!!!${C_END}\n" >&2
					continue
				fi
				# check if VPS running
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
echo -e "${C_GREEN} Hello, $USER. This is Automated migration script ${C_END}"
echo ""
echo -e "${C_GREEN} This script should be used only to migrate vps from SERVERware 1.x to SERVERware 3 ${C_END}"
echo ""

#run tests
host_check
check_remote_vps
check_local_vps

# display input informations
echo -e "MOVE VPS FROM HOST:  ${C_BLUE}$ADDR${C_END}   VPS NAME:  ${C_GREEN}$SRCDIR${C_END}   TO SERVERware 3 VPS NAME:  ${C_RED}$DESTDIR${C_END} \n "

yesno_input " Do you want to proceed?"

if [ "$?" == "0" ]; then
	# Connect to remote and rsync folders, display output in one line
	rsync -azvPh --progress --inplace --delete -e "ssh -p 2222" root@$ADDR:/vservers/$SRCDIR/opt/pbxware/ /home/lxc/$DESTDIR/rootfs/opt/pbxware/ 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	rsync -azvPh --progress --inplace --delete -e "ssh -p 2222" root@$ADDR:/vservers/$SRCDIR/opt/httpd/ /home/lxc/$DESTDIR/rootfs/opt/httpd/ 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s" && rsync -azvPh --progress --inplace --delete -e "ssh -p 2222" root@$ADDR:/vservers/$SRCDIR/home/servers/ /home/lxc/$DESTDIR/rootfs/home/servers/ 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	rsync -azvPh --progress --links --inplace --delete -e "ssh -p 2222" root@$ADDR:/vservers/$SRCDIR/etc/localtime /home/lxc/$DESTDIR/rootfs/etc/localtime 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	rsync -azvPh --progress --inplace --delete -e "ssh -p 2222" root@$ADDR:/vservers/$SRCDIR/etc/ssh/ /home/lxc/$DESTDIR/rootfs/etc/ssh/ 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	rsync -azvPh --progress --inplace --delete -e "ssh -p 2222" root@$ADDR:/vservers/$SRCDIR/root/.ssh/ /home/lxc/$DESTDIR/rootfs/root/.ssh/ 2>&1 | xargs -L1 printf "\33[2K\rTransferring: %s"
	
	# Connect to remote host and copy root password
	RPWD=$(ssh root@$ADDR -p2222 cat /vservers/$SRCDIR/etc/shadow | grep -E "^root")
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
