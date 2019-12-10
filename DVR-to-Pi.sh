#!/bin/bash

#----------------Random----------------------------------
# Good code validating website: https://www.shellcheck.net/

#----------------Installation-Steps----------------------
# 1. sudo apt-get inotify-tools ftp -y

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
UniFiDir="/var/lib/unifi-video/videos"
	# Where the videos are stored at
EdgeServer="172.16.2.12"
	# Edge server's IP address
EdgeFTPUser="Frank"
	# Edge server's user with FTP privileges
EdgeFTPPassword="<password>"
	# $EdgeFTPUser's password
EdgeNotificationsDir="notifications"
	# Directory on the edge server where notifications will be FTPed to
EdgeMotionDir="motion"
	# Directory on the edge server where motion videos will be FTPed to
#----------------Functions------------------------------
FTPToPi() {
	Ftp -4 -i user "$EdgeFTPUser" "$EdgeFTPPassword" put "$1" $EdgeServer:$EdgeMotionDir
		# FTP the motion video file to the edge server
	EditedName=$("${1//.mp4/_FTPed.mp4}")
		# Add _FTPed.mp4 to the end of the FTPed motion video
	mv "$1" "$EditedName"
		# Rename it
}
MotionCheck() {
	inotifywait -e created -t 20 "$1/meta/*.json" | while read -r "NewJSON"; do
			# Checks recursively for 20 seconds if any file has been creaed
		SendNotification
			# Since a new motion (JSON) was found, send a notification to edge server
		cd "$1" || exit
			# Just changing directories
		StartTime=$(grep 'startTime":(.*?)\,' "meta/$NewJSON")
			# Obtain motion's startTime from new JSON
		while (grep 'inProgress":(.*?)\,' "meta/$NewJSON" -eq 'true'); do
				# Detect if motion is still in progress according to the JSON
			Videos=$(grep -v "_FTPed\.mp4")
				# Grab all videos that do not contain _FTPed.mp4
			for Video in $Videos; do
				if [[ $(cut -f1 -d '_' "$Video") -ge "$StartTime" ]]; then
						# Motion video format is *_*_*_*.mp4, we take the first * and see if it is greater than or equal to the motion's startTime
					FTPToPi "$Video"
						# If true, FTP it
				fi
			done
		done
		EndTime=$(grep 'endTime":(.*?)\,' "meta/$NewJSON")
			# Obtain motion's endTime from new JSON
		Videos=$(grep -v "_FTPed\.mp4")
			# Grab all videos that do not contain _FTPed.mp4
		for Video in $Videos; do
			if [[ $(cut -f1 -d '_' "$Video") -ge "$StartTime" ]] && [[ $(cut -f1 -d '_' "$Video") -le "$EndTime" ]]; then
					# Motion video format is *_*_*_*.mp4, we take the first * and see if it is greater than or equal to the motion's startTime and less than or equal to the motion's endTime
				FTPToPi "$Video"
					# If true, FTP it
			fi
		done
	done
}
SendNotification() {
	Date=$(date +%m-%d-%Y-%H:%M)
		# Get date in a nice format (ex.11-20-2020-17:14)
	Touch "$Date.txt"
		# Create notification message to alert the farmer rather than wait for the large video file to transfer (ex.11-20-2020-17:14.txt)
	Ftp -4 -i user "$EdgeFTPUser" "$EdgeFTPPassword" put "./$Date.txt" $EdgeServer:$EdgeNotificationsDir
		# FTP a notification of motion to the edge server to beginning notification of the farmer
	rm "./$Date.txt"
		# Clean up the local notification
}

#----------------Main-----------------------------------
cd "$UniFiDir" || exit
	# Just changing directories
while $T -e "true"; do
		# Run forever
	Year=$(date +%Y)
		# Get year (ex. 2019)
	Month=$(date +%m)
		# Get month (ex. 11)
	Day=$(date +%d)
		# Get day (ex. 27)
	Cameras=$(grep '^d' "$UniFiDir")
		# Get each cameras' directory and assign it to $Cameras
	ctr='0'
	for Camera in $Cameras; do
		CameraPath[$ctr]="$UniFiDir/$Camera/$Year/$Month/$Day"
			# Add cameras' path to array $CameraPath
		MotionCheck "${CameraPath[$ctr]}" &
			# Check for motion (JSON files) at path and run in the background
		$ctr++
	done
	Wait 21
		# Wait for (inotifywait_time + 1) seconds to check for a new date
done
