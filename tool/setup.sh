#!/usr/bin/env bash
# One-time project setup. Run from anywhere:  bash tool/setup.sh
#
# 1. Generates the android/ and ios/ folders (existing files such as our
#    AndroidManifest.xml are kept).
# 2. Applies StoryCraft's native settings (bundle id, permissions, signing).
# 3. Installs packages, app icons and splash screen.
#
# Change ORG to your own reverse domain BEFORE the first run, e.g.
#   ORG=com.yourcompany bash tool/setup.sh
# The final id becomes  <ORG>.storycraft  (must be unique on both stores).
set -euo pipefail
cd "$(dirname "$0")/.."

ORG="${ORG:-com.storycraft}"

echo "==> flutter create (org: $ORG)"
flutter create --org "$ORG" --project-name storycraft --platforms android,ios .

echo "==> Native configuration"
python3 tool/configure_platforms.py

echo "==> Packages"
flutter pub get

echo "==> App icons & splash"
dart run flutter_launcher_icons
dart run flutter_native_splash:create

echo
echo "Done. Try it:  flutter run"
