#!/bin/bash

# Shows the first commit date for a file, using `git blame`.
# -Christopher Welborn 08-01-2016
appname="git-fileage"
appversion="0.0.1"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"
appdir="${apppath%/*}"

colr_file="${appdir}/colr.sh"
if [[ -f "$colr_file" ]]; then
    source "$colr_file"
    colr_auto_disable
else
    function colr {
        echo -e "$1"
    }
fi

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
        $appscript -f | -F
        $appscript [-t] [-z] FILE...

    Options:
        FILE            : One or more file names to get the initial commit
                          date for.
        -F,--firstfull  : Show the first commit(s), with full diff.
        -f,--first      : Show the first commit(s) for this repo.
        -h,--help       : Show this message.
        -t,--timestamp  : Use the raw timestamp.
        -v,--version    : Show $appname version and exit.
        -z,--timezone   : Show the committer timezone also.
    "
}

function show_first {
    # Show the first commits, with information.
    local myid
    for myid in $(git rev-list --max-parents=0 HEAD); do
        # Show the commit info, up to (not including) the 'diff' line.
        git show "$myid" | sed '/diff/q' | head -n-1
    done
}

function show_first_full {
    # Show the first commits, with information.
    local myid
    for myid in $(git rev-list --max-parents=0 HEAD); do
        # Show the commit info, up to (not including) the 'diff' line.
        git show "$myid"
    done
}

(( $# > 0 )) || fail_usage "No arguments!"

declare -a filenames
do_timestamp=0
do_timezone=0

for arg; do
    case "$arg" in
        "-f"|"--first"|"-F"|"--firstfull" )
            if [[ "$arg" == "-F" ]] || [[ "$arg" == "--firstfull" ]]; then
                show_first_full
            else
                show_first
            fi
            exit
            ;;
        "-h"|"--help" )
            print_usage ""
            exit 0
            ;;
        "-t"|"--timestamp" )
            do_timestamp=1
            ;;
        "-v"|"--version" )
            echo -e "$appname v. $appversion\n"
            exit 0
            ;;
        "-z"|"--timezone" )
            do_timezone=1
            ;;
        -*)
            fail_usage "Unknown flag argument: $arg"
            ;;
        *)
            filenames+=("$arg")
    esac
done

((${#filenames[@]})) || fail_usage "No file names given!"
for filename in "${filenames[@]}"; do
    if ! output="$(
        git blame --incremental -- "$filename" |
            awk '/committer-time/ { print $2 } /committer-tz/ { print $2 }' |
                tail -n 2)"; then
        echo_err "Error for: $filename\n  $output"
        continue
    fi
    [[ -z "$output" ]] && continue

    read -rd '' tstamp tzone <<<"$output"
    if ! ((${#tstamp} && ${#tzone})); then
        [[ -n "$output" ]] && echo_err "Missing info for $filename, got:\n  $output"
        continue
    fi
    ((do_timestamp)) || tstamp="$(date --date="@$tstamp")"
    filenamefmt="$(colr "$(printf "%25s" "$filename")" "cyan")"
    tstampfmt="$(colr "$tstamp" "blue")"
    if ((do_timezone)); then
        tzonefmt="$(colr "$tzone" "red")"
        printf "%s: %s (%s)\n" "$filenamefmt" "$tstampfmt" "$tzonefmt"
    else
        printf "%s: %s\n" "$filenamefmt" "$tstampfmt"
    fi
done
