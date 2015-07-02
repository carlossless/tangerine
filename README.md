
![](tangerine.png)

🍊 **tangerine** is a build script for building and distributing iOS apps.

## Usage

Create a configuration file based on `example.config`. Let's say `Release.config`.
Then just run the following command:

	./tangerine/tangerine configs/Release.config

## Features

Currently **tangerine** supports the following:

* Downloading the latest provisioning profile from the Apple Developer portal with [cupertino](https://github.com/nomad/Cupertino)
* Distrubution through [Crashlytics](https://crashlytics.com/)

Other less exciting features:

* [Cocoapods](http://cocoapods.org/)
* Custom keychains.
* Testing
* Building with [xcpretty](https://github.com/supermarin/xcpretty)
