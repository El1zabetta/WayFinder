#!/bin/bash
rm -rf ./mobile/стол
find . -type d \( -name "wayfinder2" -o -name "WayFinder" -o -name "стол" \) | sort
ls -la ~/flutter/bin/flutter 2>/dev/null
ls -la /opt/flutter/bin/flutter 2>/dev/null
whereis flutter
