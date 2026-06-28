#!/bin/sh
# Runs after xcodebuild completes (success or failure).
# Use this to collect logs, generate reports, or send notifications.

set -e

echo "--- Nimva CI: post-xcodebuild ---"
echo "Result: $CI_XCODEBUILD_EXIT_CODE"

if [ "$CI_XCODEBUILD_EXIT_CODE" -ne 0 ]; then
    echo "Build failed — check the Xcode Cloud log for details."
    exit 1
fi

echo "--- post-xcodebuild complete ---"
