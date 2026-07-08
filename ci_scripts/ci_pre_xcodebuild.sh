#!/bin/sh
# Runs immediately before xcodebuild.
# Use this to set build numbers, inject secrets, or validate config.

set -e

echo "--- Nimva CI: pre-xcodebuild ---"

# Auto-increment build number using the Xcode Cloud build counter.
# CI_BUILD_NUMBER is provided by Xcode Cloud automatically.
# agvtool must run from the directory containing the .xcodeproj.
if [ -n "$CI_BUILD_NUMBER" ]; then
    echo "Setting CFBundleVersion to $CI_BUILD_NUMBER"
    (cd "$CI_PRIMARY_REPOSITORY_PATH" && agvtool new-version -all "$CI_BUILD_NUMBER")
fi

echo "--- pre-xcodebuild complete ---"
