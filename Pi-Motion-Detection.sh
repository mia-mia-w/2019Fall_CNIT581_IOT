#!/bin/bash

#----------------Random----------------------------------
# vi ~/.netrc
#		machine 172.16.2.12 login Frank password <password>
# chmod 600 ~/.netrc

#----------------Installation-Steps----------------------
# 1. sudo apt-get inotify-tools ftp vsftpd git -y --force-yes
# 2. git clone https://github.com/Zamanry/2019Fall_CNIT581_IOT.git
# 3. crontab -e
# 4. 	SHELL=/bin/bash
# 5. 	MAILTO=root@example.com
# 6. 	PATH=/root
# 7.	0 * * * * /root/2019Fall_CNIT581_IOT/Pi-Motion-Detection.sh
# 8. chown root:root 2019Fall_CNIT581_IOT/Pi-Motion-Detection.sh
# 9. chmod +x 2019Fall_CNIT581_IOT/*.sh
# 10. mkdir /home/Frank/

#----------------Overall-Steps---------------------------
# 1. Detect a new JSON was created per each camera on current date
# 2. SendNotification
# 3. Get StartTime from JSON
# 4. While motion is in progress, filter for current motion videos, FTP them, and rename them with *_FTPed.mp4
# 5. When motion is done, get EndTime from JSON
# 6. Filter for current motion videos, FTP them, and rename them with *_FTPed.mp4
# 7. Restart process
#----------------Static-Variables------------------------
T="true"
LocalFTPLocation="/home/Frank"
LocalFTPNotification="notifications"
LocalFTPMotion="motion"
ScriptLocation="/root/2019Fall_CNIT581_IOT"
WebServer="172.16.1.2"
WebMotionDir="/var/www/html/camera"
Date=""
Date1=""
Check() {
	NewNotification=$(inotifywait -t 60 -e create --format '%f' "$1")
	if [ -n "$NewNotification" ]; then
		Date=$(echo "${NewNotification%%.*}")
		Date1="$Date"
		echo "Motion was detected at $Date."
		echo "Sending SMS message..."
		python /root/send_sms.py
		echo "Sent."
	fi
}

MotionCheck() {
	NewMotionDir=$(inotifywait -t 60 -e create --format '%f' "$1")
	if [ -n "$NewMotionDir" ]; then
		$ScriptLocation/FTP-Mkdir.sh "$WebServer" "$WebMotionDir" "$Date"
		sleep 5
		echo "Collecting the motion videos..."
		Videos=$(ls $1/$NewMotionDir)
			# Grab all FTPed motion videos
		for Video in $Videos; do
			$ScriptLocation/FTP.sh "$WebServer" "$WebMotionDir" "$Date" "$Video"
		done
		echo "Sent all videos."
	fi
}
#----------------Main-----------------------------------
#if [ -z "$(ps -x | grep Pi-Motion-Detection.sh)" ]; then
	# Start script if not started
	cd "$LocalFTPLocation" || exit
		# Just changing directories
	while $T -e "true"; do
		NotificationsDir="$LocalFTPLocation/$LocalFTPNotification"
		MotionDir="$LocalFTPLocation/$LocalFTPMotion"
		Check "$NotificationsDir" "$MotionDir" &
		sleep 61
	done
#else
#	echo "Script is already running. See: $(ps -x | grep Pi-Motion-Detection.sh)"
#fi
