#!/bin/sh
# Runs once after Xcode Cloud clones the repository.
# Nimva has no external package managers (no CocoaPods, no Carthage),
# so this script just validates the environment and exits.

set -e

echo "--- Nimva CI: post-clone ---"
echo "Xcode version: $(xcodebuild -version)"
echo "Swift version: $(swift --version)"
echo "Branch: $CI_BRANCH"
echo "Build number: $CI_BUILD_NUMBER"
echo "Workflow: $CI_WORKFLOW"

# SPM packages resolve automatically — no manual step needed.
# If you add CocoaPods or other tools in the future, install them here.

echo "--- post-clone complete ---"
