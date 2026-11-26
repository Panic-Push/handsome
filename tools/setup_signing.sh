#!/bin/sh
# Saves your Apple team and bundle identifier in ios/Config/Local.xcconfig.
# That file is not committed, so pulling updates never conflicts with it.
#
#   tools/setup_signing.sh YOURTEAMID [your.bundle.id]
#
# Find your Team ID in Xcode: Settings > Accounts > select your team > Team ID,
# or at developer.apple.com > Membership details.
set -e
if [ -z "$1" ]; then
  echo "Usage: tools/setup_signing.sh YOURTEAMID [your.bundle.id]"
  exit 1
fi
cd "$(dirname "$0")/.."
BUNDLE="${2:-app.penwise.dev}"
printf 'DEVELOPMENT_TEAM = %s\nPRODUCT_BUNDLE_IDENTIFIER = %s\n' "$1" "$BUNDLE" > ios/Config/Local.xcconfig
echo "Saved ios/Config/Local.xcconfig (team $1, bundle $BUNDLE)"
