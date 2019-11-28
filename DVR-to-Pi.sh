#!/bin/bash

#----------------Installation Steps----------------------
# 1. sudo apt-get inotify-tools -y

#----------------Finding-MP4-Steps----------------------
# 1. Get startTime from JSON
# 2. Get all MP4s
# 3. Cut their names for everything before the first "_"
# 4. See if the cut portion is a higher number than the startTime
#

#----------------Static-Variables------------------------
$T = "true"
$UniFiDir = "/var/lib/unifi-video/videos"
$EdgeServer = "192.168.1.45"
$EdgeUser = "pi"
$EdgePassword = "<don't insert real password here ever on GitHub>"
$EdgeNotificationsDir = "/motion-notifications"
$EdgeMotionDir = "/motion"
#----------------Functions------------------------------
MotionCheck() {
	inotifywait -r -e created -t 20 "$1/meta/*.json" | While read $WrittenFile; Do # Checks recursively for 20 seconds if any file has been written and closed for any number of cameras
	  $Date = date +%m-%d-%Y-%H:%M # Get date in a nice format (ex.11-20-2020-17:14)
	  Touch "~/$Date.txt" # Create notification message to alert the farmer rather than wait for the large video file to transfer (ex.11-20-2020-17:14.txt)
	  Ftp -4 -i user $EdgeUser $EdgePassword put "./$Date.txt" "$EdgeServer:$EdgeNotificationsDir" # FTP a notification of motion to the edge server to beginning notification of the farmer
	  rm "./$Date.txt" # Clean up the local notification
		grep 'startTime":(.*?)\,' "$1/meta/$WrittenFile" > $StartTime
		ls -l | grep "$StartTime*" > $FirstMP4
		date -r $FirstMP4 > $FirstMP4ModDate
		If (find $1 -mtime $FirstMP4ModDate && find $1 -mtime); Then
		Fi
		grep 'endTime":(.*?)\,' "$1/meta/$WrittenFile" > $EndTime
		# Need to get all .mp4 names, sort out any with names between $StartTime and $EndTime
	  Ftp -4 -i user $EdgeUser $EdgePassword put $WrittenFile $EdgeServer:$EdgeMotionDir # FTP the motion video file to the edge server
	Done
}

#----------------Main-----------------------------------
While ($T = "true"); Do
	$Year = date +%Y
	$Month = date +%m
	$Day = date +%d
	ls -l | grep '^d' > $Cameras
	$ctr = '0'
	Foreach $Camera ($Cameras)
		$CameraPath[$ctr] = "$UniFiDir/$Camera/$Year/$Month/$Day"
		MotionCheck "$CameraPath" &
		$ctr++
	End
	Wait 21
Done
