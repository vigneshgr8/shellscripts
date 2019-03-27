#!/bin/bash
echo -e "------------------------------\n Automated User Creation \n------------------------------"

# Run as root, of course
if [ $EUID -ne 0 ]; then
	echo "Must be root to run this script."
	exit
fi 

BASEDIR=$(dirname "$BASH_SOURCE")
INPUT=$1   #get Input data as CSV file

if [ -z $INPUT ]; then
	echo "Input data file path not provided!"
	exit
fi 

[ ! -f $INPUT ] && { echo "Input data file[$INPUT] not found!"; exit; }

echo "Input Data file :- $INPUT"

# No COnfigs needed now
#CONFIG_FILE=$BASEDIR/user-create.conf
#if [[ -f $CONFIG_FILE ]]; then
#    . $CONFIG_FILE
#else
#	echo "Config File not found $CONFIG_FILE, exiting"
#	exit
#fi

OLDIFS=$IFS  #need to restore IFS at the end
IFS=,

[ ! -z "$(tail -n 1 $INPUT)" ] && { echo "" >>$INPUT ; }  #lasr Row need a linebreak, add it ifit snot there

# loop for getting array values
while read -r USER_NAME OS_PSWD PHARASE GROUP_NAME
do
	[ -z "$USER_NAME" ] && { continue; }      # skip blank lines

	echo -e "\n===============================" 
	echo "Processing User : $USER_NAME"
	echo -e "===============================\n"   
    
	# Check if user already exists.
	echo "Checking Whether user already exists?  : $USER_NAME"
	
	id -u $USER_NAME
	if [ $? -eq 0 ];  then	
		echo "User $USER_NAME does already exist! Skipping this User Creation "
		continue
	fi

	# Check if Group already exists.
	echo "Checking Whether group already exists?  : $GROUP_NAME"	  
	getent group $GROUP_NAME
	if [ $? -ne 0 ]; then
		echo "Group $GROUP_NAME does not exist. creating, Group"
		groupadd $GROUP_NAME   # add new group
	fi
	GROUP_ID=$(sed -nr "s/^$GROUP_NAME:x:([0-9]+):.*/\1/p" /etc/group)
	
		 
	echo "Create a new user :$USER_NAME, Group Name: $GROUP_NAME, GROUP_ID: $GROUP_ID"	 

	ENC_OS_PSWD=`openssl passwd -1 -salt "EDFGHSV#C3efvJDD"  $OS_PSWD`     #Encrypt password

    useradd  -g $GROUP_ID -p "$ENC_OS_PSWD" -m -d "/home/$USER_NAME" -s /bin/bash "$USER_NAME"
	echo "$USER_NAME user created "
	
	echo "Generating SSH Key if it doesn't exist in : $BASEDIR/keys/$USER_NAME/id_rsa"
	
	if [ $(ls $BASEDIR/keys/$USER_NAME/ | wc -l) -eq 0 ]; then
	#rm -f $BASEDIR/keys/$USER_NAME/*     #remove if old key directory exists
	mkdir  -p $BASEDIR/keys/$USER_NAME     #path for user private key

	#ssh key generation step only if key doesn't exist
		ssh-keygen -t rsa -b 2048 -C "$USER_NAME@$(hostname)" -N "$PHARASE" -f "$BASEDIR/keys/$USER_NAME/id_rsa" -q 
		echo "Configuring ssh key.... "
	fi
    
	#Create .ssh directory for new user
	mkdir /home/$USER_NAME/.ssh  		
	chown $USER_NAME:$GROUP_NAME /home/$USER_NAME/.ssh/
	chmod 700 /home/$USER_NAME/.ssh
	touch /home/$USER_NAME/.ssh/authorized_keys

	# step for moving key file to common location
	echo "$BASEDIR/keys/$USER_NAME/id_rsa.pub key is moved to /home/$USER_NAME/.ssh/authorized_keys" 
	cp "$BASEDIR/keys/$USER_NAME/id_rsa.pub" /home/$USER_NAME/.ssh/authorized_keys
	chown $USER_NAME:$GROUP_NAME /home/$USER_NAME/.ssh/authorized_keys
	chmod 600 /home/$USER_NAME/.ssh/authorized_keys

	echo "SSH authentication setup finished User: $USER_NAME"

	# for verifying ssh access
	echo "Starting SSH Verification for $USER_NAME"
	chmod 600 $BASEDIR/keys/$USER_NAME/id_rsa
	echo "Enter following key passphrase $PHARASE"
	echo "Enter following sudo passphrase $OS_PSWD if prompted"
	ssh -n -q -i $BASEDIR/keys/$USER_NAME/id_rsa $USER_NAME@localhost exit
	if [ $? -ne 0 ]; then
		echo "SSH Verification for user $USER_NAME failed"
	else
		echo "SSH Verification for user $USER_NAME passed"
	fi
	
	
	echo "----------------------"

done < $INPUT
IFS=$OLDIFS

echo "User creation completed"
echo "----------------------"

