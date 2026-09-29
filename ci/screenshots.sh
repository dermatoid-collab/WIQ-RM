#!/bin/bash
# Runs inside xvfb-run: starts the Connect IQ simulator, loads each demo
# build and saves a screenshot of the whole virtual screen.
# Demo 1/2: sample data (edge830, edge840); demo 3: font calibration (all devices).
set -u
mkdir -p shots
"$SDK_BIN/simulator" > shots/simulator.log 2>&1 &
SIM=$!
# the simulator needs ~25 s before it accepts connections
for i in $(seq 1 30); do
  grep -q "SetLayout" shots/simulator.log && break
  sleep 3
done
sleep 5
shot() {
  local d=$1 m=$2
  local log="shots/monkeydo_${d}_${m}.log"
  for try in 1 2 3; do
    "$SDK_BIN/monkeydo" "demo/demo${m}_$d.prg" "$d" > "$log" 2>&1 &
    MD=$!
    sleep 15
    grep -q "Unable to connect" "$log" || break
    kill $MD 2>/dev/null
    sleep 5
  done
  import -window root "shots/${d}_${m}.png"
  kill $MD 2>/dev/null
  sleep 3
}
for d in edge830 edge840; do
  shot $d 1
  shot $d 2
done
for d in edge530 edge540 edge830 edge840 edge1040 edge1050; do
  shot $d 3
done
kill $SIM 2>/dev/null
ls shots
