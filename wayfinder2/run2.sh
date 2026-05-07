#!/bin/bash
rm -rf ./mobile/стол
find . -type d \( -name "wayfinder2" -o -name "WayFinder" -o -name "стол" \) | sort
