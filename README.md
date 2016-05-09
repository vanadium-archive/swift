#Vanadium & Syncbase Swift Demos

## STATUS
The Vanadium/Syncbase Swift implementation is very iOS/OS X specific at this point,
especially since the open source release Linux is very early as of this writing
(April 2016).

Currently the following are included in the iOS demo:

- "Hello world" RPC with a hard coded endpoint (discovery coming soon)
	 
- Google Sign-In OAuth used to obtain a default blessing via
	   dev.v.io. Currently broken until we update the security APIs for Syncbase.
	   
- Bluetooth discovery/advertisement tests (not using Vanadium itself, but a test hardness to validate BLE compatibility across hardware)

Requires Swift 2.2 which is available in Xcode 7.3. Any earlier versions won't
compile, and a later version of Swift will also likely cause a problem as well.

Both the demo and the libraries target iOS 9.0+. We do not support 32-bit ARM, so therefore iOS 9.0 and ARM64 are the required minimum platforms.

The project is split into the following frameworks:

- VanadiumCore.framework - This is the Swift bridge to the V23 runtime. It is intended for full Vanadium development, such as performing RPC and manual discovery management.

- SyncbaseCore.framework - This is the simple & high-level framework that abstracts away VanadiumCore and exposes a direct Swift API for Syncbase. This is a lower-level building block for Syncbase.

- Syncbase.framework - (COMING). We intend most apps will only need to work with APIs in Syncbase.framework for the near-future.

Eventually we will also distribute via Cocoapods, but until then it is required that a checkout of Vanadium is done correctly across multiple-repositories as Demo/VanadiumCore/Syncbase rely on code in the third-party repo separate from this swift-repo.

## INSTRUCTIONS
The repo does not include any of the built CGO libraries or header files.
These must be built before the demo may be compiled and run using the following instructions:

### Build the cross-compile iOS Go
In order to compile the CGO library for the iOS platform, we need to install a cross-compiling version of go first. It's important to do this for all supported platforms even if you're only planning on compiling for the simulator, because our Xcode project expects to see files for all architectures (they can be kept out of sync while developing, however). 

Install the 64-bit simulator Go profile:

	jiri profile install -target amd64-ios v23:base

Install the 64-bit device Go profile:

	jiri profile install -target arm64-ios v23:base


### To compile the CGO static libraries
For simulator only (these are equivalent)

	jiri-swift build -project SyncbaseCore build-cgo	
	# or
	jiri-swift build -project SyncbaseCore -target amd64 build-cgo

For device: 

	jiri-swift build -project SyncbaseCore -target arm64 build-cgo

For both:

	jiri-swift build -project SyncbaseCore -target all build-cgo

You may specify SyncbaseCore or VanadiumCore with the -project flags. Each are required to run their respective demos.

### To run the demos via Xcode (standard instructions)

1. Double click the Demo.xcodeproj to Xcode and open the project.
2. Make sure the Demo scheme is selected (it may already be), and choose the
   appropriate device (either a 64-bit simulator like the iPhone 5s or a
   plugged in 64-bit iPhone... 32-bit iPhone 5 & 4s is not supported currently).
   If you are unfamiliar with Xcode, look in the upper left of the project
   window and you'll see next to the Play and Stop icons a two part drop-down
   menu... the first one selects the target (chose Demo) and the second part
   selects the device (the iPhone 5S and later are 64-bit).
3. Run the project either via the menu Product > Run or the Play button in the
   upper left.