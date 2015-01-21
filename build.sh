#!/bin/bash

export SCRIPT_DIR=$(dirname "$0")
export CONFIG="$1"

config ()
{
    # A bootstrap script to run before building.
    #
    # If this file does not exist, it is not considered an error.
    : ${BOOTSTRAP="$SCRIPT_DIR/bootstrap.sh"}
    
    export BOOTSTRAP 
}

print_title ()
{
    echo ""
    echo "====== 🍺  "$1" 🍻  ======"
    export CURRENT_ACTION="$1"
}

print_title_fail ()
{
    echo "====== 💩  "$1" ❌  ======"
}

fail ()
{
    export EXIT_CODE=$1
    print_title_fail "Failed $CURRENT_ACTION"
    exit $EXIT_CODE
}

main ()
{
    config

    if [ -f "$BOOTSTRAP" ]
    then
        print_title "Bootstrapping"
        "$BOOTSTRAP" || exit $?
    fi

    print_title "Configuring"
    if [ -f "$CONFIG" ]
    then
        . "$CONFIG" || fail $?
    else
        echo "*** Couldn't find config file"
        fail 1
    fi

    export IPA_PATH=$WORKSPACE/build/$XCSCHEME.ipa
    export DSYM_PATH=$WORKSPACE/build/$XCSCHEME.xcarchive/dSYMs/$XCSCHEME.app.dSYM
    export DSYM_ZIP_PATH=$WORKSPACE/build/$XCSCHEME.app.dSYM.zip

    export XCPRETTY_FLAGS="-s"
    [ "$COLORIZED_OUTPUT" != True ] || export XCPRETTY_FLAGS="-c"

    export CURL_FLAGS="-sS"
    [ "$TEST_FLIGHT_SHOW_PROGRESS" != True ] || export CURL_FLAGS="--progress"

    [ "$KEYCHAIN" == True ] && setup_keychain
    [ "$RETRIEVE_PROFILE" == True ] && setup_profile
    [ "$COCOAPODS" == True ] && setup_pods
    clean_artifacts
    [ "$INCREASE_BUILD_NUMBER" == True ] && increase_build_number
    build_archive
    [ "$TEST" == True ] && test_application
    [ "$EXPORT_IPA" == True ] && export_ipa
    [ "$KEYCHAIN" == True ] && reset_keychain
    [ "$TEST_FLIGHT" == True ] && prepare_dsym
    [ "$TEST_FLIGHT" == True ] && submit_to_testflight
}

setup_keychain ()
{
    # Unlock Keychain
    print_title "Unlocking Keychain"
    if [ ! -f "$KEYCHAIN_PATH" ]
    then
        echo "*** Keychain File not found"
        fail 1
    fi
    security list-keychains -s "$KEYCHAIN_PATH"
    security default-keychain -d user -s "$KEYCHAIN_PATH" || fail $?
    security unlock-keychain -p $KEYCHAIN_PASSWORD "$KEYCHAIN_PATH" || fail $?
    security set-keychain-setting -l "$KEYCHAIN_PATH"
    security show-keychain-info "$KEYCHAIN_PATH"
}

function uuid_from_profile
{
    grep -aA1 UUID "$1" | grep -o "[-a-zA-Z0-9]\{36\}"
}

setup_profile ()
{
    print_title "Setting Up Profile"
    WD=$(pwd)
    mkdir -p "$WORKSPACE"/build/profiles
    cd "$WORKSPACE"/build/profiles

    rm -rf *.mobileprovision

    set -o pipefail && PROFILE=$(ios profiles:download --type distribution "$PROVISIONING_PROFILE_NAME" -u "$APPLE_DEVELOPER_USERNAME" -p "$APPLE_DEVELOPER_PASSWORD" --team "$APPLE_DEVELOPER_TEAM" | grep -Eoh "[A-Za-z0-9_]+\.mobileprovision") || fail $?
    PROFILE_UUID=$(uuid_from_profile "$PROFILE")

    export PROFILE
    export PROFILE_UUID

    if [ -n "$PROFILE_UUID" ]
    then             
        echo "Installing profile $PROFILE ($PROFILE_UUID)"
        cp -f "$PROFILE" "$HOME/Library/MobileDevice/Provisioning Profiles/${PROFILE_UUID}.mobileprovision" || fail $?
    else
        echo "*** No UUID found in $PROFILE"
    fi

    cd "$WD"
}

setup_pods ()
{
    print_title "Setting Up Pods"
    pod repo update
    pod update
}

clean_artifacts ()
{
    # Clean Previuos Artifacts
    print_title "Cleaning Artifacts"
    rm -rf $WORKSPACE/build/$XCSCHEME.xcarchive || fail $?;
    rm -f $WORKSPACE/build/$XCSCHEME.ipa || fail $?;
    rm -f build/tf_upload.log || fail $?;
}

increase_build_number ()
{
    # Increase build number
    print_title "Increasing Build Number"

    if [ -z "$EXTERNAL_BUILD_NUMBER" ] then
        set -o pipefail && PREV_BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$XCSCHEME/$XCSCHEME-Info.plist") || fail $?
    CURRENT_BUILD_NUMBER=$((PREV_BUILD_NUMBER + 1))
    else
        CURRENT_BUILD_NUMBER = "$EXTERNAL_BUILD_NUMBER"
    fi

    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CURRENT_BUILD_NUMBER" "$XCSCHEME/$XCSCHEME-Info.plist" || fail $?;
    echo "*** Previuos Build #: $PREV_BUILD_NUMBER"
    echo "*** Current Build #: $CURRENT_BUILD_NUMBER"
}

build_archive ()
{
    # Build
    print_title "Building Application"

    set -o pipefail && (xcodebuild -scheme "$XCSCHEME" -workspace "$XCWORKSPACE" -configuration "$BUILD_CONFIGURATION" clean archive -archivePath "$WORKSPACE/build/$XCSCHEME" "CODE_SIGN_IDENTITY=$CODE_SIGNING_IDENTITY" "PROVISIONING_PROFILE=$PROFILE_UUID" | xcpretty $XCPRETTY_FLAGS) || fail $?;
}

test_application ()
{
    # Test
    print_title "Testing Application"

    set -o pipefail && (xcodebuild -scheme "$XCSCHEME" -workspace "$XCWORKSPACE" -configuration "$BUILD_CONFIGURATION" -sdk iphonesimulator test | xcpretty $XCPRETTY_FLAGS -t -r junit --output "$WORKSPACE/build/junit.xml") || fail $?;
}

export_ipa ()
{
    # Export IPA
    print_title "Creating IPA File"

    xcodebuild -exportArchive -exportFormat ipa -archivePath "$WORKSPACE/build/$XCSCHEME.xcarchive" -exportPath "$IPA_PATH" -exportProvisioningProfile "$PROVISIONING_PROFILE_NAME" || fail $?;
}

reset_keychain ()
{
    security list-keychains -d user -s "${HOME}/Library/Keychains/login.keychain"
    security default-keychain -d user -s "${HOME}/Library/Keychains/login.keychain"
}

prepare_dsym ()
{
    # Prepare DSYM File
    print_title "Archiving DSYMs"

    zip -r $DSYM_ZIP_PATH $DSYM_PATH || fail $?;
}

submit_to_testflight ()
{
    # Submit to TestFlight
    print_title "Uploading to TestFlight"

    echo "*** File: $IPA_PATH"
    echo "*** DSYM: $DSYM_ZIP_PATH"
    
    set -o pipefail && curl http://testflightapp.com/api/builds.json $CURL_FLAGS -F file=@$IPA_PATH -F dsym=@$DSYM_ZIP_PATH -F api_token=$TEST_FLIGHT_API_TOKEN -F team_token=$TEST_FLIGHT_TEAM_TOKEN -F notes='Testing API' -F notify=$TEST_FLIGHT_SHOULD_NOTIFY -F distribution_lists=$TEST_FLIGHT_DISTRIBUTION_LISTS | tee >(jq ".install_url" | awk '{ print "Install URL: "$1"" }') >(jq ".config_url" | awk '{ print "Config URL:  "$1"" }') > /dev/null || fail $?;
}

main