#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open in DevToolbox
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🛠️
# @raycast.description Detect clipboard content and open it in the appropriate DevToolbox tool.
# @raycast.packageName DevToolbox

encoded=$(pbpaste | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))")
open "devtoolbox://open?input=${encoded}"
