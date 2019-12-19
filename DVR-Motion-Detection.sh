#!/bin/bash
#----------------Notes-----------------------------
# Supports additional cameras automatically
# Privileged access is permitted
# FTP only ever worked in its own script; not built-in to this one.
#----------------Installation-&-Running-Steps-on-DVR-----
# 1. SSH into DVR
# 2. sudo apt-get inotify-tools ftp git screen -y --force-yes
# 3. sudo vi ~/.netrc
#			 machine 172.16.2.12 login Frank password <password>
# 4. sudo chmod 600 ~/.netrc
# 5. git clone https://github.com/Zamanry/2019Fall_CNIT581_IOT.git
# 6. sudo chown root:root 2019Fall_CNIT581_IOT/DVR-Motion-Detection.sh
# 7. sudo chmod +x 2019Fall_CNIT581_IOT/*.sh
# 8. screen
# 9. ./2019Fall_CNIT581_IOT/DVR-Motion-Detection.sh
# 10. CTRL-A
# 11. D
#----------------motionRecording-Overall-Steps---------------------------
# 1. Detect a new JSON was created per each camera on current UTC date
# 2. Determine what event in JSON occured (motionRecording or fullTimeRecording)
# 3. SendNotification
# 4. Get startTime from JSON
# 5. While motionRecording is in progress, filter for related motion videos, FTP them, and rename them with *_FTPed.mp4. _FTPed is added to prevent files from being FTPed twice.
# 6. When motionRecording is done, get endTime from JSON
# 7. Filter for any final related motion videos, FTP them, and rename them with *_FTPed.mp4. _FTPed is added to prevent files from being FTPed twice.
# 8. Repeat
#----------------fullTimeRecording-Overall-Steps---------------------------
# 1. Detect a new JSON was created per each camera on current UTC date
# 2. Determine what event in JSON occured (motionRecording or fullTimeRecording)
# 4. Get startTime from JSON
# 4. Get endTime from JSON
# 7. Filter for any related videos, FTP them, and rename them with *_FTPed.mp4. _FTPed is added to prevent files from being FTPed twice.
# 8. Repeat
#----------------Static-Variables------------------------
T=true
	# Run script forever
UniFiDir="/srv/unifi-video/videos"
	# Where the videos are stored at
WebServer="172.16.1.2"
	# Web server's IP address
WebNotificationsDir="/var/www/html/notifications"
	# Directory on the web server where notifications will be FTPed to
WebMotionDir="/var/www/html/camera"
	# Directory on the web server where motion videos will be FTPed to
WebLiveBackupDir="/var/www/html/LiveBackups"
	# Directory on the web server where live video backups will be FTPed to
ScriptLocation="/root/2019Fall_CNIT581_IOT"
	# The parent directory of the script
Date=""
	# Leave blank; Establish $Date as a global variable
EventFound=false
	# Leave blank; Establish $EventFound as a global variable
#----------------Functions------------------------------
FTPtoPi() {
	echo "FTPing $1 to $WebServer:$2"
	$ScriptLocation/FTP.sh "$WebServer" "$2" "$Date" "$1"
		# FTP the video file to the web server
	if [ "$2" = "$WebMotionDir" ]; then
		# Only rename motion videos, not backup videos
		EditedName=$(echo "${1/.mp4/_FTPed.mp4}")
			# Add _FTPed.mp4 to the end of the FTPed motion video
		mv "$1" "$EditedName"
			# Rename it
	fi
}
JSONCheck() {
	JSON=$(inotifywait -t 15 -e create --exclude '\.(jpg|png)' --format '%f' "$1/meta/")
		# Check for new JSON files and not JPG or PNG. Output the name of the create file. Will wait here till event is found.
	if [ -n "$JSON" ]; then
		# Run only if JSON is not null
		echo "Event detected."
		cd "$1" || exit
			# Change directory to camera's UTC date
		eventType=$(grep -Po "\{\"eventType\"\:\"(.*?)\"" "meta/$JSON" | sed 's/"$//' | sed -n 's/.*"//p')
			# Obtain eventType (fullTimeRecording or motionRecording)
		echo "eventType = $eventType."
		Date=$(date +%m-%d-%Y-%H:%M)
				# Get current timezone date in a nice format (ex. 11-20-2020-17:14)-
		if [ "$eventType" = "motionRecording" ]; then
			# If eventType is a motionRecording, then
			echo "Motion JSON = $1/meta/$JSON."
			SendNotification
				# Since a new motionRecording was found, send a notification to web server
			StartTime=$(grep -Po 'startTime":(.*?),' "meta/$JSON" | sed -n 's/.*://p' | sed 's/,$//')
				# Obtain motionRecording's startTime from the JSON
			echo "startTime = $StartTime."
			echo "Making motionRecording directory at $WebServer:$WebMotionDir/$Date."
			$ScriptLocation/FTP-Mkdir.sh "$WebServer" "$WebMotionDir" "$Date"
				# Make a directory with the timestamp in the web server's motion directory
			echo "Done."
			while [ "$(grep -Po 'inProgress":(.*?),' "meta/$JSON" | sed -n 's/.*://p' | sed 's/,$//')" = true ]; do
				# Detect if motion is still in progress according to the JSON
				Videos=$(ls -p | grep -Ev "_FTPed|/|.txt")
					# Grab all items that do not contain _FTPed, a .txt, or are a directory			for Video in $Videos; do
				if [[ $(echo "$Video" | cut -f1 -d '_') -ge "$StartTime" ]]; then
						# Video name format is *_*_*_*.mp4.
						# We take the first * and see if it is greater than or equal to the motionRecording's startTime.
					FTPtoPi "$Video" "$WebMotionDir"
						# If true (video is within the time of the motionRecording), FTP it
				fi
			done
			echo "Motion is no longer in progress."
			EndTime=$(grep -Po 'endTime":(.*?),' "meta/$JSON" | sed -n 's/.*://p' | sed 's/,$//')
				# Obtain motionRecording's endTime from JSON
			echo "endTime = $EndTime."
			Videos=$(ls -p | grep -Ev "_FTPed|/|.txt")
			# Grab all items that do not contain _FTPed, a .txt, or are a directory
			for Video in $Videos; do
				if [[ $(echo "$Video" | cut -f1 -d '_') -ge "$StartTime" ]] && [[ $(echo "$Video" | cut -f2 -d '_') -le "$EndTime" ]]; then
					# Video name format is *_*_*_*.mp4.
					# We take the first * and see if it is greater than or equal to the motionRecording's startTime.
					# Then take the second * and see if it less than or equal to the motionRecording's endTime.
					FTPtoPi "$Video" "$WebMotionDir"
						# If true (video is within the time of the motionRecording), FTP it
				fi
			done
			echo "Sent all motionRecordings."
		elif [ "$eventType" = "fullTimeRecording" ]; then
			# If eventType is a fullTimeRecording, then
			echo "Live backup JSON = $1/meta/$JSON."
			StartTime=$(grep -Po 'startTime":(.*?),' "meta/$JSON" | sed -n 's/.*://p' | sed 's/,$//')
			# Obtain fullTimeRecording's startTime from the JSON
			echo "startTime = $StartTime."
			EndTime=$(grep -Po 'endTime":(.*?),' "meta/$JSON" | sed -n 's/.*://p' | sed 's/,$//')
			# Obtain fullTimeRecording's endTime from JSON
			echo "endTime = $EndTime."
			echo "Making fullTimeRecording directory at $WebServer:$WebLiveBackupDir/$Date."
			$ScriptLocation/FTP-Mkdir.sh "$WebServer" "$WebLiveBackupDir" "$Date"
			# Make a directory with the timestamp in the web server's backups directory
			Videos=$(ls -p | grep -Ev "/|.txt")
			# Grab all items that are not a .txt or directory
			for Video in $Videos; do
				if [[ $(echo "$Video" | cut -f1 -d '_') -ge "$StartTime" ]] && [[ $(echo "$Video" | cut -f2 -d '_') -le "$EndTime" ]]; then
					# Video name format is *_*_*_*.mp4.
					# We take the first * and see if it is greater than or equal to the fullTimeRecording's startTime.
					# Then take the second * and see if it less than or equal to the fullTimeRecording's endTime.
					FTPtoPi "$Video" "$WebLiveBackupDir"
						# If true (video is within the time of the fullTimeRecording), FTP it
				fi
			done
			echo "Sent all fullTimeRecordings."
		fi
		EventFound=true
	fi
}
SendNotification() {
	echo "" >> "$Date.txt"
		# Create notification message (ex. 11-20-2020-17:14.txt)
	echo "Sending motionRecording notification to $WebServer:$WebNotificationsDir/$Date."
	$ScriptLocation/DVR-Notify-FTP-Pi.sh "$WebServer" "$WebNotificationsDir" "$Date"
		# FTP a notification of motion to the web server to trigger a notification to the farmer
	echo "Done."
	rm "$Date.txt"
		# Remove the local notification
}

#----------------Main-----------------------------------
cd "$UniFiDir" || exit
	# Change script's working directory to the camera directory
while "$T" = true; do
		# Run forever
	Year=$(date +%Y -u)
		# Get UTC year (ex. 2019)
	Month=$(date +%m -u)
		# Get UTC month (ex. 11)
	Day=$(date +%d -u)
		# Get UTC day (ex. 27)
	Cameras=$(ls "$UniFiDir" | grep '^d')
		# Get each cameras' directory and assign it to $Cameras
	ctr='0'
	for Camera in $Cameras; do
		CameraPath[$ctr]="$UniFiDir/$Camera/$Year/$Month/$Day"
			# Add cameras' path to array $CameraPath
		JSONCheck "${CameraPath[$ctr]}" &
			# Check for newly created JSON files per each camera and run in the background
		ctr=$((ctr + 1))
	done
	sleep 15
	# while "$EventFound" = false; do
	# 	# This loop was setup to prevent more than one inotifywait process running at a time. As soon as an event is found, inotifywait will FTP it and mark $EventFound as true.
	# 	# This loop will see this and stop sleeping as to allow a new inotifywait process to begin.
	# 	sleep 1
	# done
	# EventFound=false
	# 	# Reset $EventFound variable
done
