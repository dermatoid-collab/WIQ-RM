#!/bin/bash
# Runs inside xvfb-run: starts the Connect IQ simulator, loads each demo
# build and saves a screenshot of the whole virtual screen.
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
for d in edge830 edge840; do
  for m in 1 2; do
    log="shots/monkeydo_${d}_${m}.log"
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
  done
done
kill $SIM 2>/dev/null
ls -la shots
