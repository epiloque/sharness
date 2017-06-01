#!/bin/sh

description="Show basic features of Sharness"

. ./sharness.sh

expectSuccess "Success is reported like this" "
    echo hello world | grep hello
"

expectSuccess "Commands are chained this way" "
    test x = 'x' &&
    test 2 -gt 1 &&
    echo success
"

return_42() {
    echo "Will return soon"
    return 42
}

expectSuccess "You can test for a specific exit code" "
    expectCode 42 return_42
"

expectFailure "We expect this to fail" "
    test 1 = 2
"

finish

# vi: set ft=sh :
