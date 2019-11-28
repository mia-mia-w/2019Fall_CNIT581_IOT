#!/bin/bash

#----------------Installation Steps----------------------
# 1. sudo apt-get inotify-tools -y

#----------------Finding-MP4-Steps----------------------
# 1. Detect a new JSON was created per each camera on current date
# 2. SendNotification
# 3. Get StartTime from JSON
# 4. Continually check if an EndTime exists in JSON
# 5. Get video files and see if firstField is greater than or equal to $StartTime and/or equal to $EndTime
# 6. FTP to edge server
# 7. Rename video
#----------------Static-Variables------------------------
T="true" # run forever
UniFiDir="/var/lib/unifi-video/videos" # Where the videos are stored at
EdgeServer="192.168.1.45" # Edge server's IP address
EdgeFTPUser="pi" # Edge server's user with FTP privileges
EdgeFTPPassword="<don't insert real password here ever on GitHub>" # $EdgeFTPUser's password
EdgeNotificationsDir="/motion-notifications" # Directory on the edge server where notifications will be FTPed to
EdgeMotionDir="/motion" # Directory on the edge server where motion videos will be FTPed to
#----------------Functions------------------------------
FTPToPi() {
	Ftp -4 -i user "$EdgeFTPUser" "$EdgeFTPPassword" put "$1" $EdgeServer:$EdgeMotionDir # FTP the motion video file to the edge server
	EditedName=$("${1//.mp4/_FTPed.mp4}")
	mv "$1" "$EditedName"
}
MotionCheck() {
	inotifywait -e created -t 20 "$1/meta/*.json" | while read -r "NewJSON"; do # Checks recursively for 20 seconds if any file has been written and closed for any number of cameras
		SendNotification
		StartTime=$(grep 'startTime":(.*?)\,' "$1/meta/$NewJSON")
		Videos=$(grep -v "_FTPed\.mp4")
		for Video in $Videos; do
			FirstField=$(cut -f1 -d '_' "$Video")
			if (grep 'endTime":(.*?)\,' "$1/meta/$NewJSON" -eq 'null'); then
				if [ "$FirstField" -ge "$StartTime" ]; then
					FTPToPi "$Video"
				fi
			else
				EndTime=$(grep 'endTime":(.*?)\,' "$1/meta/$NewJSON")
				if [ "$FirstField" -ge "$StartTime" ] && [ "$FirstField" -le "$EndTime" ]; then
					FTPToPi "$Video"
				fi
			fi
		done
	done
}
SendNotification() {
	Date=$(date +%m-%d-%Y-%H:%M) # Get date in a nice format (ex.11-20-2020-17:14)
	Touch "~/$Date.txt" # Create notification message to alert the farmer rather than wait for the large video file to transfer (ex.11-20-2020-17:14.txt)
	Ftp -4 -i user "$EdgeFTPUser" "$EdgeFTPPassword" put "./$Date.txt" $EdgeServer:$EdgeNotificationsDir # FTP a notification of motion to the edge server to beginning notification of the farmer
	rm "./$Date.txt" # Clean up the local notification
}

#----------------Main-----------------------------------
while ($T -e "true"); do # Run forever
	Year=$(date +%Y) # Get year (ex. 2019)
	Month=$(date +%m) # Get month (ex. 11)
	Day=$(date +%d) # Get day (ex. 27)
	Cameras=$(grep '^d' "$UniFiDir") # Get each cameras' directory and assign it to $Cameras
	ctr='0'
	for Camera in $Cameras; do
		CameraPath[$ctr]="$UniFiDir/$Camera/$Year/$Month/$Day" # Add cameras' path to array $CameraPath
		MotionCheck "${CameraPath[$ctr]}" & # Check for motion (JSON files) at path and run in the background
		$ctr++
	done
	Wait 21 # Wait for (inotifywait_time + 1) seconds to check for a new date
done
