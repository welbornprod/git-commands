#!/bin/bash

# Shortcut to git log -S'foo'. -G'foo', -Lstart,end:file -L/regex/:file
# -L (search for changes in a line range, or up-to/from a function/line.)
# -S (search for changes containing a certain string (additions/deletions))
# -G (search patch text for added/removed lines that match.)
# -Christopher Welborn 07-10-2016
appname="git-search"
appversion="0.0.1"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"
# appdir="${apppath%/*}"


function echo_err {
    # Echo to stderr.
    echo -e "$@" 1>&2
}

function fail {
    # Print a message to stderr and exit with an error status code.
    echo_err "$@"
    exit 1
}

function fail_usage {
    # Print a usage failure message, and exit with an error status code.
    print_usage "$@"
    exit 1
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo_err "\n$1\n"

    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript [GIT_ARGS...] [-L | -S] TERM
    Options:
        GIT_ARGS      : One or more arguments for \`git log\`.
        TERM          : Search term to find (regex).
        -h,--help     : Show this message.
        -L            : Search start/end line changes. Expects line numbers,
                        or regex can also be used as a starting/ending point.
        -S            : Look for differences that change the number of
                        occurrences of the specified string.
        -v,--version  : Show $appname version and exit.
    "
}

(( $# > 0 )) || fail_usage "No arguments!"

declare -a terms
do_S=0
do_L=0
for arg; do
    case "$arg" in
        "-h"|"--help" )
            print_usage ""
            exit 0
            ;;
        "-L" )
            do_L=1
            do_S=0
            ;;
        "-S" )
            do_L=0
            do_S=1
            ;;
        "-v"|"--version" )
            echo -e "$appname v. $appversion\n"
            exit 0
            ;;
        -*)
            fail_usage "Unknown flag argument: $arg"
            ;;
        *)
            terms+=("$arg")
    esac
done
termlen=${#terms[@]}
term="${terms[0]}"
gitargs=("${terms[@]:0:$((termlen - 1))}")
[[ -z "$term" ]] && fail_usage "No search term provided."

searchflag="-G"
((do_S)) && searchflag="-S"
((do_L)) && searchflag="-L"
echo "Searching for: $term"
git log  "$searchflag'$term'" "${gitargs[@]}"
