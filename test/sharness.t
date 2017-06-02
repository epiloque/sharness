#!/bin/sh
#
# Copyright (c) 2011-2013 Mathias Lafeldt
# Copyright (c) 2005-2013 Git project
# Copyright (c) 2005-2013 Junio C Hamano
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses/ .

description='Test Sharness itself'

. ./sharness.sh

ret="$?"

expectSuccess 'sourcing sharness succeeds' '
	test "$ret" = 0
'

expectSuccess 'success is reported like this' '
	:
'
expectFailure 'pretend we have a known breakage' '
	false
'

test_terminal () {
	perl "$SHARNESS_TEST_DIRECTORY"/test-terminal.perl "$@"
}

# If test_terminal works, then set a PERL_AND_TTY prereq for future tests:
# (PERL and TTY prereqs may later be split if needed separately)
test_terminal sh -c "test -t 1 && test -t 2" && setPrerequisite PERL_AND_TTY

run_sub_test_lib_test () {
	name="$1" descr="$2" # stdin is the body of the test code
	prefix="$3"          # optionally run sub-test under command
	opt="$4"             # optionally call the script with extra option(s)
	mkdir "$name" &&
	(
		cd "$name" &&
		cat >".$name.t" <<-EOF &&
		#!$SHELL_PATH

		description='$descr (run in sub sharness)

		This is run in a sub sharness so that we do not get incorrect
		passing metrics
		'

		# Point to the test/sharness.sh, which isn't in ../ as usual
		. "\$SHARNESS_TEST_SRCDIR"/sharness.sh
		EOF
		cat >>".$name.t" &&
		chmod +x ".$name.t" &&
		export SHARNESS_TEST_SRCDIR &&
		$prefix ./".$name.t" $opt --chain-lint >out 2>err
	)
}

check_sub_test_lib_test () {
	name="$1" # stdin is the expected output from the test
	(
		cd "$name" &&
		! test -s err &&
		sed -e 's/^> //' -e 's/Z$//' >expect &&
		compare expect out
	)
}

expectSuccess 'pretend we have a fully passing test suite' "
	run_sub_test_lib_test full-pass '3 passing tests' <<-\\EOF &&
	for i in 1 2 3
	do
		expectSuccess \"passing test #\$i\" 'true'
	done
	finish
	EOF
	check_sub_test_lib_test full-pass <<-\\EOF
	> ok 1 - passing test #1
	> ok 2 - passing test #2
	> ok 3 - passing test #3
	> # passed all 3 test(s)
	> 1..3
	EOF
"

expectSuccess 'pretend we have a partially passing test suite' "
	mustFail run_sub_test_lib_test \
		partial-pass '2/3 tests passing' <<-\\EOF &&
	expectSuccess 'passing test #1' 'true'
	expectSuccess 'failing test #2' 'false'
	expectSuccess 'passing test #3' 'true'
	finish
	EOF
	check_sub_test_lib_test partial-pass <<-\\EOF
	> ok 1 - passing test #1
	> not ok 2 - failing test #2
	#	false
	> ok 3 - passing test #3
	> # failed 1 among 3 test(s)
	> 1..3
	EOF
"

expectSuccess 'pretend we have a known breakage' "
	run_sub_test_lib_test failing-todo 'A failing TODO test' <<-\\EOF &&
	expectSuccess 'passing test' 'true'
	expectFailure 'pretend we have a known breakage' 'false'
	finish
	EOF
	check_sub_test_lib_test failing-todo <<-\\EOF
	> ok 1 - passing test
	> not ok 2 - pretend we have a known breakage # TODO known breakage
	> # still have 1 known breakage(s)
	> # passed all remaining 1 test(s)
	> 1..2
	EOF
"

expectSuccess 'pretend we have fixed a known breakage' "
	run_sub_test_lib_test passing-todo 'A passing TODO test' <<-\\EOF &&
	expectFailure 'pretend we have fixed a known breakage' 'true'
	finish
	EOF
	check_sub_test_lib_test passing-todo <<-\\EOF
	> ok 1 - pretend we have fixed a known breakage # TODO known breakage vanished
	> # 1 known breakage(s) vanished; please update test(s)
	> 1..1
	EOF
"

expectSuccess 'pretend we have fixed one of two known breakages (run in sub sharness)' "
	run_sub_test_lib_test partially-passing-todos \
		'2 TODO tests, one passing' <<-\\EOF &&
	expectFailure 'pretend we have a known breakage' 'false'
	expectSuccess 'pretend we have a passing test' 'true'
	expectFailure 'pretend we have fixed another known breakage' 'true'
	finish
	EOF
	check_sub_test_lib_test partially-passing-todos <<-\\EOF
	> not ok 1 - pretend we have a known breakage # TODO known breakage
	> ok 2 - pretend we have a passing test
	> ok 3 - pretend we have fixed another known breakage # TODO known breakage vanished
	> # 1 known breakage(s) vanished; please update test(s)
	> # still have 1 known breakage(s)
	> # passed all remaining 1 test(s)
	> 1..3
	EOF
"

expectSuccess 'pretend we have a pass, fail, and known breakage' "
	mustFail run_sub_test_lib_test \
		mixed-results1 'mixed results #1' <<-\\EOF &&
	expectSuccess 'passing test' 'true'
	expectSuccess 'failing test' 'false'
	expectFailure 'pretend we have a known breakage' 'false'
	finish
	EOF
	check_sub_test_lib_test mixed-results1 <<-\\EOF
	> ok 1 - passing test
	> not ok 2 - failing test
	> #	false
	> not ok 3 - pretend we have a known breakage # TODO known breakage
	> # still have 1 known breakage(s)
	> # failed 1 among remaining 2 test(s)
	> 1..3
	EOF
"

expectSuccess 'pretend we have a mix of all possible results' "
	mustFail run_sub_test_lib_test \
		mixed-results2 'mixed results #2' <<-\\EOF &&
	expectSuccess 'passing test' 'true'
	expectSuccess 'passing test' 'true'
	expectSuccess 'passing test' 'true'
	expectSuccess 'passing test' 'true'
	expectSuccess 'failing test' 'false'
	expectSuccess 'failing test' 'false'
	expectSuccess 'failing test' 'false'
	expectFailure 'pretend we have a known breakage' 'false'
	expectFailure 'pretend we have a known breakage' 'false'
	expectFailure 'pretend we have fixed a known breakage' 'true'
	finish
	EOF
	check_sub_test_lib_test mixed-results2 <<-\\EOF
	> ok 1 - passing test
	> ok 2 - passing test
	> ok 3 - passing test
	> ok 4 - passing test
	> not ok 5 - failing test
	> #	false
	> not ok 6 - failing test
	> #	false
	> not ok 7 - failing test
	> #	false
	> not ok 8 - pretend we have a known breakage # TODO known breakage
	> not ok 9 - pretend we have a known breakage # TODO known breakage
	> ok 10 - pretend we have fixed a known breakage # TODO known breakage vanished
	> # 1 known breakage(s) vanished; please update test(s)
	> # still have 2 known breakage(s)
	> # failed 3 among remaining 7 test(s)
	> 1..10
	EOF
"

setPrerequisite HAVEIT
haveit=no
expectSuccess HAVEIT 'test runs if prerequisite is satisfied' '
	havePrerequisite HAVEIT &&
	haveit=yes
'
donthaveit=yes
expectSuccess DONTHAVEIT 'unmet prerequisite causes test to be skipped' '
	donthaveit=no
'
if test $haveit$donthaveit != yesyes
then
	say "bug in test framework: prerequisite tags do not work reliably"
	exit 1
fi

setPrerequisite HAVETHIS
haveit=no
expectSuccess HAVETHIS,HAVEIT 'test runs if prerequisites are satisfied' '
	havePrerequisite HAVEIT &&
	havePrerequisite HAVETHIS &&
	haveit=yes
'
donthaveit=yes
expectSuccess HAVEIT,DONTHAVEIT 'unmet prerequisites causes test to be skipped' '
	donthaveit=no
'
donthaveiteither=yes
expectSuccess DONTHAVEIT,HAVEIT 'unmet prerequisites causes test to be skipped' '
	donthaveiteither=no
'
if test $haveit$donthaveit$donthaveiteither != yesyesyes
then
	say "bug in test framework: multiple prerequisite tags do not work reliably"
	exit 1
fi

clean=no
expectSuccess 'tests clean up after themselves' '
	whenFinished clean=yes
'

if test $clean != yes
then
	say "bug in test framework: basic cleanup command does not work reliably"
	exit 1
fi

expectSuccess 'tests clean up even on failures' "
	mustFail run_sub_test_lib_test \
		failing-cleanup 'Failing tests with cleanup commands' <<-\\EOF &&
	expectSuccess 'tests clean up even after a failure' '
		touch clean-after-failure &&
		whenFinished rm clean-after-failure &&
		(exit 1)
	'
	expectSuccess 'failure to clean up causes the test to fail' '
		whenFinished \"(exit 2)\"
	'
	finish
	EOF
	check_sub_test_lib_test failing-cleanup <<-\\EOF
	> not ok 1 - tests clean up even after a failure
	> #	Z
	> #	touch clean-after-failure &&
	> #	whenFinished rm clean-after-failure &&
	> #	(exit 1)
	> #	Z
	> not ok 2 - failure to clean up causes the test to fail
	> #	Z
	> #	whenFinished \"(exit 2)\"
	> #	Z
	> # failed 2 among 2 test(s)
	> 1..2
	EOF
"

expectSuccess 'cleanup functions run at the end of the test' "
	run_sub_test_lib_test cleanup-function 'Empty test with cleanup function' <<-\\EOF &&
	cleanup 'echo cleanup-function-called >&5'
	finish
	EOF
	check_sub_test_lib_test cleanup-function <<-\\EOF
	1..0
	cleanup-function-called
	EOF
"

expectSuccess 'We detect broken && chains' "
	mustFail run_sub_test_lib_test \
		broken-chain 'Broken && chain' <<-\\EOF
	expectSuccess 'Cannot fail' '
		true
		true
	'
	finish
	EOF
"

expectSuccess 'tests can be run from an alternate directory' '
	# Act as if we have an installation of sharness in current dir:
	ln -sf $SHARNESS_TEST_SRCDIR/sharness.sh . &&
	export working_path="$(pwd)" &&
	cat >test.t <<-EOF &&
	description="test run of script from alternate dir"
	. \$(dirname \$0)/sharness.sh
	expectSuccess "success" "
		true
	"
	finish
	EOF
        (
          # unset SHARNESS variables before sub-test
	  unset SHARNESS_TEST_DIRECTORY SHARNESS_TEST_SRCDIR &&
	  # unset HARNESS_ACTIVE so we get a test-results dir
	  unset HARNESS_ACTIVE &&
	  chmod +x test.t &&
	  mkdir test-rundir &&
	  cd test-rundir &&
	  ../test.t >output 2>err &&
	  cat >expected <<-EOF &&
	ok 1 - success
	# passed all 1 test(s)
	1..1
	EOF
	  compare expected output &&
	  test -d test-results
	)
'

expectSuccess 'SHARNESS_ORIG_TERM propagated to sub-sharness' "
	(
	  export TERM=foo &&
	  unset SHARNESS_ORIG_TERM &&
	  run_sub_test_lib_test orig-term 'check original term' <<-\\EOF
	expectSuccess 'SHARNESS_ORIG_TERM is foo' '
		test \"x\$SHARNESS_ORIG_TERM\" = \"xfoo\" '
	finish
	EOF
	)
"

[ -z "$color" ] || setPrerequisite COLOR
expectSuccess COLOR,PERL_AND_TTY 'sub-sharness still has color' "
	run_sub_test_lib_test \
	  test-color \
	  'sub-sharness color check' \
	  test_terminal <<-\\EOF
	expectSuccess 'color is enabled' '[ -n \"\$color\" ]'
	finish
	EOF
"

expectSuccess 'EXPENSIVE prereq not activated by default' "
	run_sub_test_lib_test no-long 'long test' <<-\\EOF &&
	expectSuccess 'passing test' 'true'
	expectSuccess EXPENSIVE 'passing suposedly long test' 'true'
	finish
	EOF
	check_sub_test_lib_test no-long <<-\\EOF
	> ok 1 - passing test
	> ok 2 # skip passing suposedly long test (missing EXPENSIVE)
	> # passed all 2 test(s)
	> 1..2
	EOF
"

expectSuccess 'EXPENSIVE prereq is activated by --long' "
	run_sub_test_lib_test long 'long test' '' '--long' <<-\\EOF &&
	expectSuccess 'passing test' 'true'
	expectSuccess EXPENSIVE 'passing suposedly long test' 'true'
	finish
	EOF
	check_sub_test_lib_test long <<-\\EOF
	> ok 1 - passing test
	> ok 2 - passing suposedly long test
	> # passed all 2 test(s)
	> 1..2
	EOF
"

expectSuccess 'loading sharness extensions works' '
	# Act as if we have a new installation of sharness
	# under `extensions` directory. Then create
	# a sharness.d/ directory with a test extension function:
	mkdir extensions &&
	(
		cd extensions &&
		mkdir sharness.d &&
		cat >sharness.d/test.sh <<-EOF &&
		this_is_a_test() {
			return 0
		}
		EOF
		ln -sf $SHARNESS_TEST_SRCDIR/sharness.sh . &&
		cat >test-extension.t <<-\EOF &&
		description="test sharness extensions"
		. ./sharness.sh
		expectSuccess "extension function is present" "
			this_is_a_test
		"
		finish
		EOF
		unset SHARNESS_TEST_DIRECTORY SHARNESS_TEST_SRCDIR &&
		chmod +x ./test-extension.t &&
		./test-extension.t >out 2>err &&
		cat >expected <<-\EOF &&
		ok 1 - extension function is present
		# passed all 1 test(s)
		1..1
		EOF
		compare expected out
	)
'

expectSuccess 'empty sharness.d directory does not cause failure' '
	# Act as if we have a new installation of sharness
	# under `extensions` directory. Then create
	# an empty sharness.d/ directory
	mkdir nil-extensions &&
	(
		cd nil-extensions &&
		mkdir sharness.d  &&
		ln -sf $SHARNESS_TEST_SRCDIR/sharness.sh . &&
		cat >test.t <<-\EOF &&
		description="sharness works"
		. ./sharness.sh
		expectSuccess "test success" "
			/bin/true
		"
		finish
		EOF
		unset SHARNESS_TEST_DIRECTORY SHARNESS_TEST_SRCDIR &&
		chmod +x ./test.t &&
		./test.t >out 2>err &&
		cat >expected <<-\EOF &&
		ok 1 - test success
		# passed all 1 test(s)
		1..1
		EOF
		compare expected out
	)
'

expectSuccess INTERACTIVE 'Interactive tests work' '
    echo -n "Please type yes and hit enter " &&
    read -r var &&
    test "$var" = "yes"
'

finish

# vi: set ft=sh :
