#!/bin/sh
# Runs immediately before xcodebuild.
# Use this to set build numbers, inject secrets, or validate config.

set -e

echo "--- Nimva CI: pre-xcodebuild ---"

# Auto-increment build number using the Xcode Cloud build counter.
# CI_BUILD_NUMBER is provided by Xcode Cloud automatically.
if [ -n "$CI_BUILD_NUMBER" ]; then
    echo "Setting CFBundleVersion to $CI_BUILD_NUMBER"
    /usr/libexec/PlistBuddy \
        -c "Set :CFBundleVersion $CI_BUILD_NUMBER" \
        "$CI_PRIMARY_REPOSITORY_PATH/Nimva/Info.plist" 2>/dev/null || \
    agvtool new-version -all "$CI_BUILD_NUMBER"
fi

echo "--- pre-xcodebuild complete ---"
