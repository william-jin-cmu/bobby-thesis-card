#!/bin/zsh
# record.sh state seconds — record one auto-playing tour clip
cd "$(dirname "$0")"
SIM="${SIM:-booted}"
xcrun simctl terminate "$SIM" com.williamjin.bobbyproto 2>/dev/null; sleep 0.8
mkdir -p clips
xcrun simctl io "$SIM" recordVideo --codec h264 --force clips/$1.mov >/dev/null 2>&1 &
rp=$!; sleep 1.2
xcrun simctl launch "$SIM" com.williamjin.bobbyproto -demo $1 -tour >/dev/null
sleep $2
kill -INT $rp; wait $rp 2>/dev/null
ffprobe -v error -show_entries format=duration -of csv=p=0 clips/$1.mov
