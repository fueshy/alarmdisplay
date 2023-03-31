#!/bin/bash

cat << "EOF"
#                               
#   /\ | _  _ _  _|. _ _ | _    
#  /--\|(_|| |||(_||_)|_)|(_|\/ 
#                     |      /  
#                   __          
#   _ _|_    _       _)         
#  _)(-|_|_||_)  \/ /__         
#           |                   

EOF

# check prerequisits

if ! command -v cec-client &> /dev/null
then
  apt update -y && apt install cec-utils -y
else
  echo "cec-client already installed";
fi

if ! command -v jq &> /dev/null
then
  apt update -y && apt install jq -y
else
  echo "jq already installed";
fi

if ! command -v chromium-browser &> /dev/null
then
    apt update -y && apt install chromium-browser -y
else
    echo "chromium already installed";
fi

CONFDIR="/etc/fwgk"
CONFFILE="alarmdisplay.conf"
RUNDIR="/opt/fwgk"
RUNFILE="groupAlarmDisplay.sh"
WORKERFILE="worker.sh"

if [ -d "${CONFDIR}" ]
then
  echo "Directory $CONFDIR found. Performing update instead."
  #exit 1
else
  echo "Directory $CONFDIR not found. Will create it for you."
  mkdir $CONFDIR

  touch $CONFDIR/$CONFFILE

  cd $CONFDIR

cat > $CONFFILE <<\EOF
APITOKEN='abcde'
APIURI='https://app.groupalarm.com/api/v1'
ORGID=''

#TODO: allow multiple CEC clients
CECCLEINT='0.0.0.0'

#time after display powerstatus changes to standby
TIMEBEFORESHUTDOWN=3600

#time between api rechecks
TIMEAPICHECK=120

VIEWTOKEN=''
VIEWTHEME=dark-theme
VIEWURI='https://app.groupalarm.com/de/monitor/7556'
EOF

fi

if [ -d "${RUNDIR}" ]
then
  echo "Directory $RUNDIR found. Will overwrite it"
  rm -rf $RUNDIR
fi

mkdir $RUNDIR
cd $RUNDIR
cat > $RUNFILE <<EOF
#!/bin/bash
source ${CONFDIR}/${CONFFILE}

if test -f ${RUNDIR}/${WORKERFILE}; then
  source ${RUNDIR}/${WORKERFILE}
  rm -f ${RUNDIR}/${WORKERFILE}
fi

EOF

chmod +x $RUNFILE

cat >> $RUNFILE <<\EOF
exec 100>/var/tmp/$(basename "$0").lock || exit 1
flock -n 100 || exit 1
echo "Doing some stuff…"
sleep ${TIMEAPICHECK}

### check open events
RESPONSE=$(curl -s --request GET '${APIURI}/events?organization=${APIURI}&filter=open' --header 'API-TOKEN: ${APITOKEN}')
OPENEVENTS=`jq '.totalEvents' <(echo "$RESPONSE")`

if test $OPENEVENTS -eq 0
then
  #nothing
  #echo "Test";
  exit 0
fi

echo 'on '$CECCLIENT  | cec-client -s -d 1
echo 'as' | cec-client -s -d 1

sleep ${TIMEBEFORESHUTDOWN}
echo 'standby' '$CECCLIENT | cec-client -s -d 1
exit 0;

EOF

cat > $WORKERFILE <<EOF
#!/bin/bash
source ${CONFDIR}/${CONFFILE}
EOF

cat >> $WORKERFILE <<\EOF
#TODO: check if already exist
echo "@chromium-browser --noerrdialogs --kiosk --incognito ${VIEWURI}?view_token=${VIEWTOKEN}&theme=${VIEWTHEME}" >> /home/pi/.config/lxsession/LXDE-pi/autostart

#check if values from confdir differ to runfile

EOF

chmod +x $WORKERFILE


echo "files written."

#TODO check am i on a pi?
echo ""
echo "@xset s off" >> /home/pi/.config/lxsession/LXDE-pi/autostart
echo "@xset -dpms" >> /home/pi/.config/lxsession/LXDE-pi/autostart
echo "@xset s noblank" >> /home/pi/.config/lxsession/LXDE-pi/autostart



echo "#######################################################"
echo "# set custom config in $CONFDIR/$CONFFILE    #"
echo "# run crontab -e manually and add the following line: #"
echo "# * * * * * ${RUNDIR}/${RUNFILE}            #"
echo "#######################################################"

rm -- "$0"
exit 0;

