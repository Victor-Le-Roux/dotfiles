#!/usr/bin/env bash

usage=$(df -P / | awk 'NR==2 {gsub("%", "", $5); print $5}')

if [ -z "$usage" ]; then
  usage=0
fi

echo "DSK ${usage}%"
