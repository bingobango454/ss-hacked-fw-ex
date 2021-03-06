#!/bin/bash
#
# rc.M		This file is executed by init(8) when the system is being
#		initialized for one of the "multi user" run levels (i.e.
#		levels 1 through 6).

# Bind magic folders:
if [ -e /etc/magic_folders/folders.cfg ]; then
    if ! egrep -qo "^nomagic( |\$)" /etc/bootcmd.cfg; then
	echo "Binding magic folders:"
	num=`grep -c / /etc/magic_folders/folders.cfg`; x=1
	while [ $x -le $num ]; do
	    # Source:
	    src=`sed -n "$x"p /etc/magic_folders/folders.cfg | cut -d" " -f1`
	    # UUID to sdXY translation:
	    uuid=`echo $src | cut -d/ -f3`; dev=`blkid -U $uuid | cut -d/ -f3`; src=`echo $src | sed s/$uuid/$dev/g`
	    # Destination:
	    dest=`sed -n "$x"p /etc/magic_folders/folders.cfg | cut -d" " -f2`
	    if [ -f $src ]; then
		# fsck for magic .dat containers:
		draw() { echo "[1;33m""---------------------------------------------------------""[0m"; }
		fsck_dat() { echo "performing filesystem check on $1"
		fs=`blkid $1 | egrep -o ' TYPE=[^ ]+' | cut -b8-10`
		if [ $fs = xfs ]; then
		    echo "detected xfs - performing fsck at mount time"
		elif [ $fs = ext ]; then
		    draw; e2fsck -C 0 -p $1; wait; draw
		elif [ $fs = rei ]; then
		    draw; reiserfsck -p $1; wait; draw
		else
		    echo "detected unsupported fs - skipping fsck"
		fi }
		echo "mount -o loop $src $dest"
		if file $src | grep -qo LUKS; then
		    let y=`losetup -a | tail -n1 | cut -d: -f1 | sed s^/dev/loop^^`+1
		    losetup /dev/loop$y $src
		    cryptsetup luksOpen /dev/loop$y magic$y && sleep 2
		    fsck_dat /dev/mapper/magic$y
		    mount /dev/mapper/magic$y $dest
		else
		    fsck_dat $src
		    mount -o loop $src $dest
		fi
	    else
		echo "mount -o bind $src $dest"
		mount -o bind $src $dest
	    fi
	let x=x+1
	done
	# Restart syslog when magic folders are used on /var folder:
	grep -qo ' /var' /etc/magic_folders/folders.cfg && [ -x /etc/rc.d/rc.syslog ] && sh /etc/rc.d/rc.syslog restart >/dev/null &
    fi
fi

# Initialize loopback interface:
ifconfig lo 127.0.0.1 2>/dev/null &
route add -net 127.0.0.0 netmask 255.0.0.0 lo 2>/dev/null &

# Initialize the networking hardware:
[ -x /etc/rc.d/rc.inet1 ] && . /etc/rc.d/rc.inet1 &

# Start ACPI daemon:
if ! egrep -qo "^acpi=off( |\$)" /etc/bootcmd.cfg; then
	[ -x /etc/rc.d/rc.acpid ] && /usr/sbin/acpid -n &
fi

# Start NetworkManager:
[ -x /etc/rc.d/rc.networkmanager ] && /usr/sbin/NetworkManager &

# Set correct permissions in the system:
chmod 1777 /dev/shm /tmp /var/tmp 2>/dev/null
chmod 700 /root

# Run SystemV init scripts for this runlevel:
[ -x /etc/rc.d/rc.sysvinit ] && . /etc/rc.d/rc.sysvinit

# Add entry for hotplugged devices to fstab:
echo -e "\n# Hotplugged devices:" >> /etc/fstab

# Add removable devices back to the fstab:
for prt in `cat /mnt/live/tmp/ejected 2>/dev/null`; do echo add >/sys/class/block/$prt/uevent 2>/dev/null; done

# Start PXE services:
egrep -qo "^pxe( |\$)" /etc/bootcmd.cfg && sh /opt/porteus-scripts/pxe-server

                                               
                                                                                     
# Delete ICE locks                          
if [ -d /tmp/.ICE-unix ]; then                                        
    rm -rf /tmp/.ICE-unix/*                     
else                                               
    mkdir /tmp/.ICE-unix
fi                               
chown root:root /tmp/.ICE-unix/             
chmod 1777 /tmp/.ICE-unix

# Start other services in the background:
sh /etc/rc.d/rc.services >/dev/null 2>&1 &

# Update xdg directories if they exist
for a in `ls -1 /home` root; do
	if [ `getent passwd $a` ]; then
		[ -e /usr/bin/xdg-user-dirs-update ] && su -l $a -c '/usr/bin/xdg-user-dirs-update --force &'
	fi
done

# If cliexec= cheatcode is present, automatically start the command given.
# If you need to execute several commands, separate them using ';'
# If you need to use spaces in your command, use '~' instead
# If you wish to reboot/poweroff after the command's execution is finished,
# simply use cliexec=yourCommand;poweroff for example.
CMD=`egrep -o "^cliexec=[^ ]+" /etc/bootcmd.cfg | cut -d= -f2 | tr "~" " "`
[ -z "$CMD" ] || { echo "Starting 'cliexec=' commands"; su - -c "$CMD"; }

# Set the hostname.                                    
if [ -r /etc/HOSTNAME ]; then           
  /bin/hostname $(/bin/cat /etc/HOSTNAME) &                
else                
  # fall back on this old default:                                
  echo "porteus.example.net" > /etc/HOSTNAME
  /bin/hostname porteus.example.net &          
fi 

# Start the local setup procedure:
[ -x /etc/rc.d/rc.local ] && . /etc/rc.d/rc.local

# All done.
