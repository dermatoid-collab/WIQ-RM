#!/bin/bash
# Runs inside xvfb-run: starts the Connect IQ simulator, loads each demo
# build and saves a screenshot of the whole virtual screen.
set -u
mkdir -p shots
"$SDK_BIN/simulator" > shots/simulator.log 2>&1 &
SIM=$!
sleep 12
for d in edge830 edge840; do
  for m in 1 2; do
    "$SDK_BIN/monkeydo" "demo/demo${m}_$d.prg" "$d" > "shots/monkeydo_${d}_${m}.log" 2>&1 &
    MD=$!
    sleep 12
    import -window root "shots/${d}_${m}.png"
    kill $MD 2>/dev/null
    sleep 2
  done
done
kill $SIM 2>/dev/null
ls -la shots
