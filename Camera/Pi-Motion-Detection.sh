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
T=true
	# Run script forever
LocalFTPLocationDir="/var/www/html"
	# Parent directory of all FTP directories
LocalFTPBackupsDir="LiveBackups"
	# Directory of fullTimeRecordings
LocalFTPMotionDir="camera"
	# Directory of motionRecordings
LocalFTPNotificationDir="notifications"
	# Directory of motionRecording notifications
ScriptLocationDir="/root/2019Fall_CNIT581_IOT"
	# The parent directory of the script
SendSMSLocation="/root/send_sms.py"
	# Location of send SMS Python script
Date=""
	# Leave blank; Establish $Date as a global variable
EventFound=""
	# Leave blank; Establish $EventFound as a global variable
NotificationCheck() {
	NewNotification=$(inotifywait -t 15 -e create --format '%f' "$1")
		# Check for new txt files. Output the name of the create file. Will wait here till event is found.
	Date=$(echo "${NewNotification%%.*}")
		# Get motionRecording's timestamp.
	echo "Motion was detected at $Date."
	echo "Sending SMS message..."
	python3 "$SendSMSLocation"
	echo "Done."
	EventFound=true
}
#----------------Main-----------------------------------
cd "$LocalFTPLocationDir" || exit
# Change script's working directory to the parent directory of all FTP directories
while $T = true; do
	NotificationCheck "$LocalFTPLocationDir/$LocalFTPNotificationDir" &
 #MotionCheck "$LocalFTPLocation/$LocalFTPMotionDir" &
	#while "$EventFound" = false; do
		# This loop was setup to prevent more than one inotifywait process running at a time. As soon as an event is found, inotifywait will FTP it and mark $EventFound as true.
		# This loop will see this and stop sleeping as to allow a new inotifywait process to begin.
		sleep 15
		if [ "$(find "$LocalFTPLocationDir/$LocalFTPBackupsDir" -mtime +3)" -ne "$null" ]; then
			# Made to not constantly be deleting files. Only when time is older than three days.
			echo "Deleting any camera archives older than three days."
			find "$LocalFTPLocationDir/$LocalFTPMotionDir" -mtime +3 -exec rm -f {} \;
			find "$LocalFTPLocationDir/$LocalFTPBackupsDir" -mtime +3 -exec rm -f {} \;
			find "$LocalFTPLocationDir/$LocalFTPNotificationDir" -mtime +3 -exec rm -f {} \;
			echo "Done."
		fi
	# done
	# EventFound=false
		# Reset $EventFound variable
done
