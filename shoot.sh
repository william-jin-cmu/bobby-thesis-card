#!/bin/zsh
# shoot.sh state [wait] [name]  — relaunch app into a demo state and screenshot
cd "$(dirname "$0")"
SIM="${SIM:-booted}"
mkdir -p shots
xcrun simctl terminate "$SIM" com.williamjin.bobbyproto 2>/dev/null
xcrun simctl launch "$SIM" com.williamjin.bobbyproto -demo $1 >/dev/null
sleep ${2:-3}
xcrun simctl io "$SIM" screenshot shots/${3:-$1}.png >/dev/null 2>&1
sips -Z 1000 shots/${3:-$1}.png --out ${TMPDIR:-/tmp}/sim-${3:-$1}.png >/dev/null
