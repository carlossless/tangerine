# Tangerine

**Tangerine** is a build script for building and distributing iOS apps.

## Usage

Create a configuration file based on `example.config`. Let's say `Release.config`.
Then just run the following command:

	./tangerine/build.sh configs/Release.config

## Features

Currently **Tangerine** supports the following:

* Downloading the latest provisioning profile from the Apple Developer portal with [cupertino](http://)
* Distrubution through [TestFlight](http://)

Other less exciting features:

* [Cocoapods](http://)
* Custom keychains.
* Testing
* Building with [xctool](http://)