#Vanadium Swift Demos

## STATUS
The Vanadium Swift implementation is very iOS/OS X specific at this point,
especially since the open source release Linux is very early as of this writing
(April 2016).

Currently the following are included in the iOS demo:

- "Hello world" RPC with a hard coded endpoint (discovery coming soon)
	 
- Google Sign-In OAuth used to obtain a default blessing via
	   dev.v.io.

Requires Swift 2.2 which is available in Xcode 7.3. Any earlier versions won't
compile, and a later version of Swift will also likely cause a problem as well.

The demo also targets iOS 9.0+, although the Vanadium libraries target 8.0+

There are two Vanadium frameworks that the demo uses:

- VanadiumCore.framework - This is the Swift bridge to the V23 runtime. It is intended for full Vanadium development, such as performing RPC and manual discovery management.

- Syncbase.framework - This is the simple & high-level framework that abstracts away VanadiumCore and exposes a direct Swift API for Syncbase. We intend most apps will only need to work with APIs in Syncbase.framework for the near-future.

Eventually we will also support Cocoapods, but until then it is required that a checkout of Vanadium is done correctly across multiple-repositories as Demo/VanadiumCore/Syncbase rely on code in the third-party repo separate from this swift-repo.

## INSTRUCTIONS
The repo does not include any of the built CGO libraries or header files.
These must be built before the demo may be compiled and run.

### Build the cross-compile iOS Go
In order to compile the CGO library for the iOS platform, we need to install a cross-compiling version of go first. It's important to do this for all supported platforms even if you're only planning on compiling for the simulator, because our Xcode project expects to see files for all architectures (they can be kept out of sync while developing, however). 

Install the 64-bit simulator Go profile:

	jiri profile install -target amd64-ios v23:base

Install the 64-bit device Go profile:

	jiri profile install -target arm64-ios v23:base


### To compile the CGO static libraries
For simulator only (these are equivalent)

	jiri-swift build build-cgo	
	# or
	jiri-swift build -target amd64 build-cgo	

For device: 

	jiri-swift build -target arm64 build-cgo

For both:

	jiri-swift build -target all build-cgo


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