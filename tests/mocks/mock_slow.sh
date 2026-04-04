#!/bin/sh
# Mock: sleeps then returns (for spinner/cancel testing)
cat >/dev/null
sleep 10
echo "slow result"
