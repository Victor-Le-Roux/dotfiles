#!/usr/bin/env bash

mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
mem_available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)

if [ -z "$mem_total" ] || [ "$mem_total" -le 0 ]; then
  echo "RAM 0%"
  exit 0
fi

used=$((mem_total - mem_available))
usage=$((100 * used / mem_total))

echo "RAM ${usage}%"
