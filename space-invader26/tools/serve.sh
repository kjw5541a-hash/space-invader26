#!/bin/sh
# Space Invader 로컬 서버 관리 (LaunchAgent, 재부팅 후에도 자동 실행)
# 사용법: sh tools/serve.sh [start|stop|restart|status]  (기본값 status)
PLIST="$HOME/Library/LaunchAgents/com.spaceinvader.serve.plist"
GUI="gui/$(id -u)"
URL="http://localhost:8901/build/web/game.html"
cmd="${1:-status}"
case "$cmd" in
  stop) launchctl bootout "$GUI/com.spaceinvader.serve" 2>/dev/null; echo "stopped";;
  start) launchctl bootstrap "$GUI" "$PLIST" 2>/dev/null; sleep 1
    curl -s -o /dev/null -w "http:%{http_code}\n" "$URL";;
  restart) launchctl bootout "$GUI/com.spaceinvader.serve" 2>/dev/null; sleep 1
    launchctl bootstrap "$GUI" "$PLIST" 2>/dev/null; sleep 1
    curl -s -o /dev/null -w "http:%{http_code}\n" "$URL";;
  *) curl -s -o /dev/null -w "status http:%{http_code}\n" "$URL";;
esac
