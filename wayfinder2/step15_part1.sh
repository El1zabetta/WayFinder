#!/bin/bash
# 1. Confirm not referenced by active code/config
# Grep was already done in the previous step and yielded nothing for 'стол'.

# 2. Compare ./mobile/стол/WayFinder/wayfinder2 and current dir (which is wayfinder2)
diff -r -q --exclude=.git --exclude=.venv --exclude=mobile/стол . ./mobile/стол/WayFinder/wayfinder2 > diff_output.txt

# 3. Delete ./mobile/стол
rm -rf ./mobile/стол

# 4. Find what remains
find . -type d \( -name "wayfinder2" -o -name "WayFinder" -o -name "стол" \) | sort > find_output.txt

# 5. Flutter checks
ls -la ~/flutter/bin/flutter > flutter_check.txt 2>&1
ls -la /opt/flutter/bin/flutter >> flutter_check.txt 2>&1
whereis flutter >> flutter_check.txt 2>&1
