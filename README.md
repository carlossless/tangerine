# tangerine

**tangerine** is a build script for building and distributing iOS apps.

## Usage

Create a configuration file based on `example.config`. Let's say `Release.config`.
Then just run the following command:

	./tangerine/build.sh configs/Release.config

## Features

Currently **tangerine** supports the following:

* Downloading the latest provisioning profile from the Apple Developer portal with [cupertino](https://github.com/nomad/Cupertino)
* Distrubution through [TestFlight](https://www.testflightapp.com)

Other less exciting features:

* [Cocoapods](http://cocoapods.org/)
* Custom keychains.
* Testing
* Building with [xctool](https://github.com/facebook/xctool)