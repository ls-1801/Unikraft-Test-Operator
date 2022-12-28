#!/usr/bin/env bash
# This script automates the process of deploying unikraft built images 
# to GCP's Compute service.
#

#################################################
################ Global Defines #################
#################################################
GREEN="\e[92m"
LIGHT_BLUE="\e[94m"
RED="\e[31m"
LIGHT_RED="\e[91m"
GRAY_BG="\e[100m"
UNDERLINE="\e[4m"
BOLD="\e[1m"
END="\e[0m"

# Cloud specific global constants
# Default values, if not provided to the script. 
PROJECT="unikraft"
BASE_NAME="unikraft"
ZONE="europe-west3-c"
INSTYPE="f1-micro"
NAME=${BASE_NAME}-`date +%s`
TAG="http-server"

# System specific global vars
ERROR="ERROR:"
LOG="${NAME}-log.uk"

# List of required tools 
req_tools=(
"gcloud"
)

#################################################
############### Helper Functions ################
#################################################

# Gives script usage information to the user
function usage() {   
   echo "usage: $0 [-h] [-v] -k <unikernel> -b <bucket> [-n <name>]"
   echo "       [-z <zone>] [-i <instance-type>] [-t <tag>] [-v] [-s]"
   echo ""
   echo -e "${UNDERLINE}Mandatory Args:${END}"
   echo "<unikernel>: 	  Raw Disk"
   echo "<bucket>: 	  GCP bucket name"
   echo ""
   echo -e "${UNDERLINE}Optional Args:${END}"
   echo "<name>: 	  Image name to use on the cloud (default: ${BASE_NAME})"
   echo "<zone>: 	  GCP zone (default: ${ZONE})"
   echo "<instance-type>:  Specify the type of the machine on which you wish to deploy the unikernel (default: ${INSTYPE}) "
   echo "<tag>:		  Tag is used to identify the instances when adding network firewall rules (default: ${TAG})"
   echo "<-v>: 		  Turns on verbose mode"
   echo "<-s>: 		  Automatically starts an instance on the cloud"
   echo ""
   exit 1
}
# Directs the script output to data sink
log_pause() {
if [ -z "$V" ]
then
	exec 6>&1
	exec &>> $LOG
fi
}

# Restores/Resumes the script output to STGCPUT
log_resume() {
if [ -z "$V" ]
then
	exec >&6
fi
}

# If any command fails in script, this function will be invoked to handle the error.
function handle_error() {
	log_resume
	echo -e "${LIGHT_RED}[FAILED]${END}"
	echo -e "${LIGHT_RED}Error${END} on line:$1"
	if [ -z "$V" ]
	then
		echo -e "For more details, please see ${LIGHT_BLUE}$LOG${END} file, or run the script with verbose mode ${GRAY_BG}-v${END}" 
	fi
	clean
	exit 1
}

function handle_output() {
local cmd_out=$1
local status
status=$( echo $cmd_out | awk 'NR==1 {print $1;}' )
if [ ${status} == ${ERROR} ]
then
        echo -e "${LIGHT_RED}[FAILED]${END}"
	echo $cmd_out
	clean
	exit 1
else
	echo -e "${GREEN}[OK]${END}"
fi
}

function create_image() {
echo -n "Creating image on the cloud.............."
OUTPUT=$( gcloud compute images -q create  $NAME --source-uri gs://$BUCKET/$TAR_FILE 2>&1 )
handle_output "$OUTPUT"
}

function delete_image() {
echo -n "Deleting existing image.................."
OUTPUT=$( gcloud compute images delete $NAME --quiet 2>&1 )
handle_output "$OUTPUT"
}

function create_bucket() {
echo -n "Creating bucket on the cloud............."
log_pause
gsutil mb gs://${BUCKET};sts_code=$?;ln=$LINENO
echo ------$sts_code
if [ "$sts_code" -ne 0 ];then
	handle_error $ln
fi
log_resume
echo -e "${GREEN}[OK]${END}"
}

#################################################
################ Main Routine ###################
#################################################

# Process the arguments given to script by user
while getopts "vshk:n:b:z:i:t:" opt; do
 case $opt in
 h) usage;;
 n) NAME=$OPTARG ;;
 b) BUCKET=$OPTARG ;;
 z) ZONE=$OPTARG ;;
 k) DISK=$OPTARG ;;
 i) INSTYPE=$OPTARG ;;
 t) TAG=$OPTARG ;;
 v) V=true ;;
 s) S=true ;;
 esac
done

shift $((OPTIND-1))

# Take root priviledge for smooth execution
${SUDO} echo "" >/dev/null

# set error callback
trap 'handle_error $LINENO' ERR

# Check if provided image file exists.
if [ ! -e "$DISK" ]; then
  echo "Please specify a unikraft image with mandatory [-k] flag."
  echo "Run '$0 -h' for more help"
  exit 1
fi

if [ -z $BUCKET ];
then
	echo "Please specify bucket-name with mandatory [-b] flag."
	echo "Run '$0 -h' for more help"
	exit 1
else
	log_pause
	gsutil ls -b gs://${BUCKET} || create_bkt=true
	log_resume
fi

# Check if required tools are installed
for i in "${req_tools[@]}"
do
   type $i >/dev/null 2>&1 || { echo -e "Tool Not Found: ${LIGHT_BLUE}$i${END}\nPlease install : $i\n${LIGHT_RED}Aborting.${END}"; exit 1;}
done


echo -e "Deploying ${LIGHT_BLUE}${DISK}${END} on Google Cloud..."
echo -e "${BOLD}Name  :${END} ${NAME}"
echo -e "${BOLD}Bucket:${END} ${BUCKET}"
echo -e "${BOLD}Zone  :${END} ${ZONE}"
echo ""

TAR_FILE="$NAME.tar.gz"

echo "Creating tarfile "
tar -zcf $TAR_FILE disk.raw
echo "Uploading (previous image having same name will be overwritten) "
gsutil mv $TAR_FILE gs://$BUCKET/$TAR_FILE
log_resume
echo -e "${GREEN}[OK]${END}"
# Check if image already exists
IMG_STATUS=`gcloud compute images list --filter="name=($NAME)"`
if [ -z "$IMG_STATUS" ]
then
	create_image
else
	echo -e "${LIGHT_RED}An image already exists on cloud with the name: ${LIGHT_BLUE}${NAME}${END}${END}"
	echo -n "Would you like to delete the existing image and create new one (y/n)?"
	read choice
	case "$choice" in
		y|Y )	delete_image
			create_image ;;
		n|N ) echo "Please change the image name and try again." 
			exit 1 ;;
		* ) echo "Invalid choice. Please enter y|Y or n|N"
			exit 1 ;;
	esac
fi

if [ -z "$S" ]
then
        echo ""
        echo "To run the instance on GCP, use following command-"
	echo -e "${GRAY_BG}gcloud compute instances -q create $INSTANCE_NAME --image $NAME --machine-type $INSTYPE --zone $ZONE --tags $TAG ${END}"
else
        echo -n "Starting instance on the cloud..........."
        log_pause
        # This echo maintains the formatting
        echo ""
        # Start an instance on the cloud
		gcloud compute instances --quiet create $INSTANCE_NAME --image $NAME --machine-type $INSTYPE --zone $ZONE --tags $TAG > tmp_inst_info
        log_resume
        echo -e "${GREEN}[OK]${END}"
fi
log_resume
echo ""
echo -e "${UNDERLINE}NOTE:${END}"
echo "1) To see the GCP system console log, use following command-"
echo -e "${GRAY_BG} gcloud compute instances get-serial-port-output $INSTANCE_NAME --zone=${ZONE} ${END}"
echo "2) GCP takes some time to initialise the instance and start the booting process, If there is no output on serial console, Please run it again in few secs"
echo "3) Don't forget to customise GCP with proper firewall settings (if no --tags are given),"
echo "as the default one won't let any inbound traffic in."
echo ""
