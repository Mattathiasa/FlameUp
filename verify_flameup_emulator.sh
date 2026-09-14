#!/usr/bin/env bash
# verify_flameup_emulator.sh — E2E check: emulators up -> app talks to them.
# Run from the FlameUp project root:
#   bash verify_flameup_emulator.sh
set -uo pipefail
SIM=2509D127-4541-4DB7-BF75-F9C113334E49
BID=com.flameup.app

echo "== emulators online check =="
for port in 9099 8080 5001 9199 4000; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$port/" 2>/dev/null)
  echo "  port $port -> http $code"
done

echo
echo "== install + launch app (built with config/emulator.env) =="
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app || exit 1
xcrun simctl launch "$SIM" "$BID" || exit 1

sleep 8
if xcrun simctl spawn "$SIM" launchctl list 2>/dev/null | grep -q "$BID"; then
  echo "PASS: app is running against the emulator suite"
else
  echo "FAIL: app exited"
  exit 1
fi
