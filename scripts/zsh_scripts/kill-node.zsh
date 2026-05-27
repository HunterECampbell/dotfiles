#!/usr/bin/env zsh
# Kill node processes whose command line includes --port (e.g. dev servers)

function kill-node-processes() {
  pkill -f 'node.*--port' 2>/dev/null || true
}
