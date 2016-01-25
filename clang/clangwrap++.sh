#!/bin/sh
# This uses the latest available iOS SDK, which is recommended.
# To select a specific SDK, run 'xcodebuild -showsdks'
# to see the available SDKs and replace iphoneos with one of them.
if [ "$GOARCH" == "arm" ] || [ "$GOARCH" == "armv7" ] || [ "$GOARCH" == "arm64" ]; then
  # echo "Building for iPhone OS"
  SDK=iphoneos
else
  # echo "Building for iPhone Simulator"
  SDK=iphonesimulator
fi

SDK_PATH=`xcrun --sdk $SDK --show-sdk-path`
export IPHONEOS_DEPLOYMENT_TARGET=8.0
CLANG=`xcrun --sdk $SDK --find clang++`

if [ "$GOARCH" == "arm" ] || [ "$GOARCH" == "armv7" ]; then
  CLANGARCH="armv7"
elif [ "$GOARCH" == "arm64" ]; then
  CLANGARCH="arm64"
elif [ "$GOARCH" == "386" ]; then
  CLANGARCH="i386"
elif [ "$GOARCH" == "amd64" ]; then
  CLANGARCH="x86_64"
else
  echo "unknown GOARCH=$GOARCH" >&2
  exit 1
fi

# TODO(zinman) Go currently doesn't support bitcode. Perhaps in 1.6 we can emit it.
# See https://github.com/golang/go/issues/12682
#exec $CLANG -arch $CLANGARCH -isysroot $SDK_PATH -fembed-bitcode "$@"
exec $CLANG -arch $CLANGARCH -isysroot $SDK_PATH "$@"