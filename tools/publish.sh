#!/bin/sh
# 웹 빌드 후 gh-pages 브랜치에 발행 (GitHub Pages는 gh-pages 루트 서빙)
# 사용법: sh tools/publish.sh
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
  echo "main에서 실행해주세요 (현재: $BRANCH)"
  exit 1
fi
godot --headless --path . --export-release "Web" build/web/game.html
TMP=$(mktemp -d)
git clone -q . "$TMP/pub"
cd "$TMP/pub"
if git show-ref --verify --quiet refs/heads/gh-pages; then
  git checkout -q gh-pages
elif git show-ref --verify --quiet refs/remotes/origin/gh-pages; then
  git checkout -q -b gh-pages origin/gh-pages
else
  git checkout -q --orphan gh-pages
fi
git rm -qrf . >/dev/null 2>&1 || true
cp -r "$ROOT/build/web/"* .
cat > index.html <<'EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="0; url=game.html">
<title>Space Invader 2.5D</title>
</head>
<body style="background:#000;color:#fff;text-align:center;font-family:sans-serif;padding-top:40px;">
<p>로딩 중… <a href="game.html" style="color:#0ff;">바로 플레이</a></p>
</body>
</html>
EOF
git add -A
git commit -qm "Publish $(date +%F_%H%M)"
git push -q origin gh-pages
cd "$ROOT"
rm -rf "$TMP"
git push -q origin gh-pages
echo "published to gh-pages"
