#!/bin/bash

if [ $(id -u) -eq 0 ]; then
	echo "Welcome to the user addition script. 
The script will ask for your username-password list file. Please make sure it is in the following format.
		user1 password1
		user2 password2
		user3 password3
		...
The script will also ask for the ssh-key path

"
	read -p "Enter the file name for the user list file with path: " ufile
	read -p "Enter the path to the folder to store the ssh-keys: " keypath
	while read u1 p1
	do
		useradd -m "$u1"
		echo User $u1 added
		su $u1 -c "yes "" | ssh-keygen -q -t rsa -f "/home/$u1/.ssh/id_rsa$u1""
		echo ${u1}:${p1} | chpasswd
		echo Temporary password set
		usermod -a -G sudo "$u1"
		echo Added user to sudo group
		chage -d 0 "$u1"
		echo "$u1 will be asked to change password at first login"
		mkdir $keypath
		cp /home/$u1/.ssh/id_rsa$u1 $keypath/
		echo Keys copied
		echo User $u1 creation and configuration complete\!

	done < $ufile

else
	echo "Only root may add a user to the system"
	exit 2
fi
