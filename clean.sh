#!/bin/sh
# Clean up XCode project files and built products

rm -fr MailCore.xcodeproj/project.xcworkspace/
rm -fr MailCore.xcodeproj/xcuserdata/
rm -fr build/
rm -fr libetpan/build-mac/build/
rm -fr libetpan/build-mac/libetpan.xcodeproj/xcuserdata/