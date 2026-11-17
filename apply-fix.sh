#!/bin/sh
# Applies the proposed one-line SystemBars fix to node_modules/@capacitor/android.
# Run after `npm install`; then `npx cap sync android` and rebuild. Another `npm install` undoes it.
set -e
F=node_modules/@capacitor/android/capacitor/src/main/java/com/getcapacitor/plugin/SystemBars.java
if grep -q 'content.setPadding(' "$F"; then echo "fix already applied"; exit 0; fi
patch -p1 < systembars-scrim-fix.patch
echo "fix applied to $F"
