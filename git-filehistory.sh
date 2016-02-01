#!/bin/bash

# Shortcut to `git log --follow -p -- FILE`
# -Christopher Welborn 07-11-2015
appname="git-filehistory"
appversion="0.0.2"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo -e "\n$1\n"

    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript [-c] [GIT_LOG_ARGS...] FILE

    Options:
        GIT_LOG_ARGS  : Any extra arguments to pass to \`git log\`.
        FILE          : File name to get history for.
                        Must be the last argument.
        -c,--commits  : Show commits instead of diffs.
        -h,--help     : Show this message.
        -v,--version  : Show $appname version and exit.
    "
}

if [[ $# -eq 0 ]]; then
    print_usage "No arguments!"
    exit 1
fi

declare -a args
show_commits=0
for arg; do
    case "$arg" in
        "-h"|"--help" )
            print_usage ""
            exit 0
            ;;
        "-v"|"--version" )
            echo -e "$appname v. $appversion\n"
            exit 0
            ;;
        "-c"|"--commits" )
            show_commits=1
            ;;
        * )
            args=("${args[@]}" "$arg")
            ;;
    esac
done

filename="${args[-1]}"
unset args[-1]
if ((! show_commits)); then
    args=("${args[@]}" "-p")
fi
# echo "Running: git log --follow ${args[@]} -- $filename"
git log --follow "${args[@]}" -- "$filename"
