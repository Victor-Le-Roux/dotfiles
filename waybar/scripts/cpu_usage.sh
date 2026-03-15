#!/usr/bin/env bash

read -r _ u1 n1 s1 i1 w1 irq1 sirq1 st1 _ < /proc/stat
total1=$((u1 + n1 + s1 + i1 + w1 + irq1 + sirq1 + st1))
idle1=$((i1 + w1))

sleep 0.2

read -r _ u2 n2 s2 i2 w2 irq2 sirq2 st2 _ < /proc/stat
total2=$((u2 + n2 + s2 + i2 + w2 + irq2 + sirq2 + st2))
idle2=$((i2 + w2))

dt=$((total2 - total1))
di=$((idle2 - idle1))

if [ "$dt" -le 0 ]; then
  echo "CPU 0%"
  exit 0
fi

usage=$(( (100 * (dt - di)) / dt ))
echo "CPU ${usage}%"
