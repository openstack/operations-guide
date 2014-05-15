#!/bin/bash

function setup_directory {
    SET_LANG=$1
    shift
    for BOOK_DIR in "$@" ; do
        openstack-generate-docbook -l $SET_LANG -b $BOOK_DIR
    done
}


function test_manuals {
    SET_LANG=$1
    shift
    for BOOK in "$@" ; do
        echo "Building $BOOK for language $SET_LANG..."
        setup_directory $SET_LANG $BOOK
        openstack-doc-test --check-build -l $SET_LANG --only-book $BOOK
        RET=$?
        if [ "$RET" -eq "0" ] ; then
            echo "... succeeded"
        else
            echo "... failed"
            BUILD_FAIL=1
        fi
    done
}

function test_all {
    test_manuals 'ja' 'openstack-ops'
}


BUILD_FAIL=0
test_all

exit $BUILD_FAIL
