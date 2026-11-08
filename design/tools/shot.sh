#!/bin/sh
# shot.sh <Board.dc.html> [width height] -> design/tools/shots/<Board>.png
# Screenshots a design artboard with headless Chrome through design/tools/serve.js
# (start it first: node design/tools/serve.js &). Works while the app window is hidden.
D="$(cd "$(dirname "$0")" && pwd)/shots"; mkdir -p "$D"
N="${1%.dc.html}"; OUT="$(cygpath -w "$D/$N.png")"
W=${2:-390}; H=${3:-844}
"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --virtual-time-budget=4000 --window-size=$W,$H --screenshot="$OUT" \
  "http://127.0.0.1:5179/preview.html?f=$1&still=1&w=$W&h=$H" >/dev/null 2>&1
echo "$OUT"
