#!/bin/sh
# Simple sleep monitor (Harvie 2012)
#
# You probably have soundcard with one output and input
# Take PIR motion sensor from security system
# Use PIR to switch connection between left channels of output and input (tips of 3.5mm jacks)
# Connect grounds of these two together (maybe you will not need it - depending on your soundcard)
# Power up PIR
# Launch this script
# Use alsamixer and some GUI recorder (like audacity) to tune volume to some usable level
# Place PIR facing to your bed and go sleep
# Wake up
# Enjoy your data


out=/tmp/sleeplog-"$(date +%F_%T)".txt
speaker-test -t sine &>/dev/null &
pid_test=$!
tresh=10
lastdate="$(date +%s)"
laststate=0
history='';
historymax=120;
historylen='10 30 120'
screen=false
while getopts "s" OPT; do
	test "$OPT" == 's' && screen=true;
done
echo "Writing to file: $out";
arecord | ./goertzel -n i -q -l c -t $tresh -d 4 | while read line; do
	date="$(date +%s)"
	time="$(echo "$line" | cut -f 1)"
	level="$(echo "$line" | cut -f 2)"
	test "$level" -gt "$tresh" && state=false || state=true
	$state && statenum=1 || statenum=0;
	$state && statename='MOTION!' || statename='Nothing';

	echo -ne "$time\t$date $(date '+%F %T') $statenum"

	#History
	after=$(( $date - $lastdate))
	test $historymax -gt 0 && {
		history=$(echo -n "$(yes | tr '\ny' $laststate | head -c $after)$history" | head -c $historymax)
		for len in $historylen; do
			on="$(echo -n ${history::$len} | tr -d 0 | wc -c)"
			on="$(echo "scale=2; $on/$len" | bc)"
			LC_ALL=C printf " %.2f" "$on"
		done
	}

	#Debug
	echo -e "\t($statename $level After $after secs)";

	#Fun with values
	$state && {
		$screen && xset dpms force off || true;
	} || {
		$screen && xset dpms force on;
	}
	./sleepplot.sh "$out" &>/dev/null &

	#Prepare invariants for next round
	lastdate="$date";
	laststate="$statenum";
done | tee "$out"
kill $pid_test
echo
echo "Your file: $out"
