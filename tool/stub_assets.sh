#!/usr/bin/env bash
# Fills in the paths pubspec.yaml declares as assets, for a checkout that does
# not have them: res/ is not in the repository because it holds ~2.8 GB of
# videos (see README).
#
# The build only needs the declared paths to exist, while the smoke test wants a
# playable stream, so the paths get the tiny H.264 fixture from test/fixtures.
# When the checkout already has the real assets the script does nothing.
set -euo pipefail

cd "$(dirname "$0")/.."

size=0
if [ -f res/global/loading.mp4 ]; then
  size=$(wc -c < res/global/loading.mp4)
fi
if [ "${size}" -gt 1000000 ]; then
  echo "res/ already holds the media assets; keeping them"
  exit 0
fi

# 1x1 opaque PNG, so that no binary has to be stored for the covers.
cover_png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGPg5eUFAABSACgr+S0sAAAAAElFTkSuQmCC'

for work in anon soyo sakiko tomori mutsumi viola; do
  mkdir -p "res/works/${work}/segments"
  printf '%s' "${cover_png}" | base64 -d > "res/works/${work}/cover.png"
done

mkdir -p res/global
for target in res/global/loading.mp4 res/global/background.mp4 res/icon.png; do
  cp test/fixtures/loading.mp4 "${target}"
done

echo "stubbed the declared assets with test/fixtures/loading.mp4"
