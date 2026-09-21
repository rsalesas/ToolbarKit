#!/bin/sh
# Builds TitlebarDemo.app into Examples/TitlebarDemo/build/ as a plain,
# ad-hoc signed app that can be copied to another Mac and run without Xcode.
set -e
cd "$(dirname "$0")"
xcodegen generate --quiet
xcodebuild -project TitlebarDemo.xcodeproj -scheme TitlebarDemo -configuration Release \
  -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- -quiet build
rm -rf build/TitlebarDemo.app
cp -R build/DerivedData/Build/Products/Release/TitlebarDemo.app build/TitlebarDemo.app
echo "Built build/TitlebarDemo.app"
