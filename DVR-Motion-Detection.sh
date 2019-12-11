#!/bin/bash

#----------------Random----------------------------------
# Good code validating website: https://www.shellcheck.net/
# vi ~/.netrc
#		machine 172.16.2.12 login Frank password <password>
# chmod 600 ~/.netrc

#----------------Installation-Steps----------------------
# 1. sudo apt-get inotify-tools ftp git -y --force-yes
# 2. git clone https://github.com/Zamanry/2019Fall_CNIT581_IOT.git
# 3. crontab -e
# 4. 	SHELL=/bin/bash
# 5. 	MAILTO=root@example.com
# 6. 	PATH=/root
# 7.	0 * * * * /root/2019Fall_CNIT581_IOT/DVR-Motion-Detection.sh
# 8. chown root:root 2019Fall_CNIT581_IOT/DVR-Motion-Detection.sh
# 9. chmod +x 2019Fall_CNIT581_IOT/*.sh

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
	# run forever
UniFiDir="/srv/unifi-video/videos"
	# Where the videos are stored at
EdgeServer="172.16.2.12"
	# Edge server's IP address
EdgeNotificationsDir="notifications"
	# Directory on the edge server where notifications will be FTPed to
EdgeMotionDir="motion"
	# Directory on the edge server where motion videos will be FTPed to
ScriptLocation="/root/2019Fall_CNIT581_IOT"
Date=""
	# Establish a global Date variable
#----------------Functions------------------------------
FTPtoPi() {
	echo "FTPing $1 to $EdgeServer:$EdgeMotionDir"
	$ScriptLocation/FTP.sh "$EdgeServer" "$EdgeMotionDir" "$Date" "$1"
		# FTP the motion video file to the edge server
	EditedName=$(echo "${1/.mp4/_FTPed.mp4}")
		# Add _FTPed.mp4 to the end of the FTPed motion video
	mv "$1" "$EditedName"
		# Rename it
}
MotionCheck() {
	newjson=$(inotifywait -t 60 -e create --exclude '\.(jpg|png)' --format '%f' "$1/meta/")
	if [ -n "$newjson" ]; then
		echo "Created file was named $1/meta/$newjson."
			# Checks recursively for 20 seconds if any file has been created
		Date=$(date +%m-%d-%Y-%H:%M)
				# Get date in a nice format (ex.11-20-2020-17:14)
		SendNotification
			# Since a new motion (JSON) was found, send a notification to edge server
		cd "$1" || exit
			# Just changing directories
		StartTime=$(grep -Po 'startTime":(.*?),' "meta/$newjson" | sed -n 's/.*://p' | sed 's/,$//')
			# Obtain motion's startTime from new JSON
		echo "Making $Date directory at $EdgeServer:$EdgeMotionDir"
		$ScriptLocation/FTP-Mkdir.sh "$EdgeServer" "$EdgeMotionDir" "$Date"
			# Make a directory with the timestamp in the Pi's motion folder
		echo "inProgress = $(grep -Po 'inProgress":(.*?),' "meta/$newjson" | sed -n 's/.*://p' | sed 's/,$//')"
		while [ "$(grep -Po 'inProgress":(.*?),' "meta/$newjson" | sed -n 's/.*://p' | sed 's/,$//')" = 'true' ]; do
			# Detect if motion is still in progress according to the JSON
			Videos=$(ls -p | grep -Ev "_FTPed|/")
				# Grab all videos that do not contain _FTPed.mp4
			for Video in $Videos; do
				if [[ $(echo "$Video" | cut -f1 -d '_') -ge "$StartTime" ]]; then
						# Motion video format is *_*_*_*.mp4, we take the first * and see if it is greater than or equal to the motion's startTime
					echo "startTime = $StartTime"
					FTPtoPi "$Video"
						# If true, FTP it
				fi
			done
		done
		echo "inProgress = $(grep -Po 'inProgress":(.*?),' "meta/$newjson" | sed -n 's/.*://p' | sed 's/,$//')"
		EndTime=$(grep -Po 'endTime":(.*?),' "meta/$newjson" | sed -n 's/.*://p' | sed 's/,$//')
			# Obtain motion's endTime from new JSON
		echo "endTime = $EndTime."
		Videos=$(ls -p | grep -Ev "_FTPed|/")
			# Grab all videos that do not contain _FTPed.mp4
		for Video in $Videos; do
			if [[ $(echo "$Video" | cut -f1 -d '_') -ge "$StartTime" ]] && [[ $(echo "$Video" | cut -f2 -d '_') -le "$EndTime" ]]; then
					# Motion video format is *_*_*_*.mp4, we take the first * and see if it is greater than or equal to the motion's startTime and less than or equal to the motion's endTime
				FTPtoPi "$Video"
					# If true, FTP it
			fi
		done
		echo "Sent all videos."
	fi
}
SendNotification() {
	echo "$null" >> "$Date.txt"
		# Create notification message to alert the farmer rather than wait for the large video file to transfer (ex.11-20-2020-17:14.txt)
	echo "FTPing $Date notification to $EdgeServer:$EdgeNotificationsDir"
	$ScriptLocation/DVR-Notify-FTP-Pi.sh "$EdgeServer" "$EdgeNotificationsDir" "$Date"
		# FTP a notification of motion to the edge server to beginning notification of the farmer
	rm "$Date.txt"
		# Clean up the local notification
}

#----------------Main-----------------------------------
#if [ -z "$(ps x | grep DVR-Motion-Detection.sh)" ]; then
	# Start script if not started
	cd "$UniFiDir" || exit
		# Just changing directories
	while $T -e "true"; do
			# Run forever
		Year=$(date +%Y -u)
			# Get year (ex. 2019)
		Month=$(date +%m -u)
			# Get month (ex. 11)
		Day=$(date +%d -u)
			# Get day (ex. 27)
		Cameras=$(ls "$UniFiDir" | grep '^d')
			# Get each cameras' directory and assign it to $Cameras
		ctr='0'
		for Camera in $Cameras; do
			CameraPath[$ctr]="$UniFiDir/$Camera/$Year/$Month/$Day"
				# Add cameras' path to array $CameraPath
			MotionCheck "${CameraPath[$ctr]}" &
				# Check for motion (JSON files) at path and run in the background
			ctr=$((ctr + 1))
		done
		sleep 61
			# Wait for (inotifywait_time + 1) seconds to check for a new date
	done
#else
#	echo "Script is already running. See: $(ps x | grep DVR-Motion-Detection.sh)"
#fi
