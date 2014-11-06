#!/bin/bash

export SCRIPT_DIR=$(dirname "$0")

config ()
{
    # A whitespace-separated list of executables that must be present and locatable.
    : ${REQUIRED_TOOLS="xctool pod jq"}
    
    export REQUIRED_TOOLS
}

main ()
{
    config

    if [ -n "$REQUIRED_TOOLS" ]
    then
        echo "*** Checking dependencies..."
        check_deps
    fi
}

check_deps ()
{
    for tool in $REQUIRED_TOOLS
    do
        which -s "$tool"
        if [ "$?" -ne "0" ]
        then
            echo "*** Error: $tool not found. Please install it and bootstrap again."
            exit 1
        fi
    done
}

main