#!/bin/bash

# Shows the first commit date for a file, using `git blame`.
# -Christopher Welborn 08-01-2016
appname="git-fileage"
appversion="0.2.1"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"
appdir="${apppath%/*}"

colr_file="${appdir}/colr.sh"
if hash colrc &>/dev/null; then
    function colr {
        # Even wrapped in a function, this is still faster than colr.sh and colr.py.
        colrc "$@"
    }
elif [[ -f "$colr_file" ]]; then
    # shellcheck source=/home/cj/scripts/git-commands/colr.sh
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

function fileage {
    # Show the first commit date for a file.
    # Arguments:
    #   $1 : File path to show first commit date for.
    local output rev tstamp tzone
    # Example revision: c0a8b544a6c82d92468a77d21dce28201661866f
    # shellcheck disable=SC2016
    local revpat='length($1) == 40 { print $1 }'
    # shellcheck disable=SC2016
    local timepat='/committer-time/ { print $2 }'
    # shellcheck disable=SC2016
    local tzpat='/committer-tz/ { print $2 }'
    local filenamefmt tstampfmt tzonefmt revfmt

    # Get revision.
    if ! output="$(git blame --incremental -- "$filename" | awk "$revpat" | tail -n1)"; then
        echo_err "Error for: $filename\n$output"
        return 1
    fi
    [[ -z "$output" ]] && return 1
    rev=$output
    # Get time/timezone
    if ! output="$(
        git blame --incremental -- "$filename" |
            awk "$timepat $tzpat" |
                tail -n 2)"; then
        echo_err "Error for: $filename\n  $output"
        return 1
    fi
    [[ -z "$output" ]] && return 1
    read -rd '' tstamp tzone <<<"$output"
    if ! ((${#tstamp} && ${#tzone})); then
        [[ -n "$output" ]] && echo_err "Missing info for $filename, got:\n  $output"
        return 1
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
    if ((do_commit)); then
        local indent="                           "
        revfmt="$(colr "$rev" "yellow")"
        printf "%s%s\n" "$indent" "$revfmt"
        local author authorfmt
        author="$(git log "$rev" --pretty='format:%an' -n1)"
        authorfmt="$(colr "$author" "green")"
        printf "%sAuthor: %s\n\n" "$indent" "$authorfmt"
        local subj subjfmt
        subj="$(git log "$rev" --pretty='format:%s' -n1)"
        subjfmt="$(colr "$subj" "lightblue")"
        printf "%s%s\n\n" "$indent" "$subjfmt"
        local bodyline linefmt
        # Indent all lines in the body.
        while IFS=$'\n' read -r bodyline; do
            # Ignore blanks.
            [[ -n "$bodyline" ]] || continue
            linefmt="$(colr "$bodyline" "cyan")"
            printf "%s%s\n" "$indent" "$linefmt"
        done < <(git log "$rev" --pretty='format:%b' -n1)
        printf "\n"
    else
        printf "\n"
    fi
    return 0
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo_err "\n$1\n"

    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript -f | -F [GIT_SHOW_ARGS...]
        $appscript [-c] [-t] [-z] FILE...

    Options:
        FILE             : One or more file names to get the initial commit
                           date for.
        GIT_SHOW_ARGS    : Extra arguments for \`git show <commit_id>\`.
        -c,--commit      : Show the first commit for the file.
        -F,--firstfull   : Show the first commit(s) in this repo, with full diff.
        -f,--first       : Alias for \`$appscript -F --no-patch\`.
                           Only the commit header is shown, not the diff.
        -h,--help        : Show this message.
        -t,--timestamp   : Use the raw timestamp.
        -v,--version     : Show $appname version and exit.
        -z,--timezone    : Show the committer timezone also.
    "
}

function show_first {
    # Show the first commits, with information.
    # Arguments:
    #   $@  : Extra arguments for `git show`.
    local myid

    for myid in $(git rev-list --max-parents=0 HEAD); do
        # Show the commit info,using git show args to determine the format.
        git show "$@" "$myid"
    done
}

(( $# > 0 )) || fail_usage "No arguments!"

declare -a nonflags
do_timestamp=0
do_timezone=0
do_first=0
do_first_full=0
do_commit=0

for arg; do
    case "$arg" in
        "-c"|"--commit" )
            do_commit=1
            ;;
        "-f"|"--first" )
            do_first=1
            ;;
        "-F"|"--firstfull" )
            do_first=1
            do_first_full=1
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
            if ((do_first)); then
                nonflags+=("$arg")
            else
                fail_usage "Unknown flag argument: $arg"
            fi
            ;;
        *)
            nonflags+=("$arg")
            ;;
    esac
done

declare -a extra_args
if ((do_first)); then
    if ((! do_first_full)); then
        # Add --no-patch arg as a default for -f,--first.
        [[ "${nonflags[*]}" =~ (--no-patch)|(-s ) ]] || extra_args+=("--no-patch")
    fi
    show_first "${extra_args[@]}" "${nonflags[@]}"
    exit
fi

# File ages.
((${#nonflags[@]})) || fail_usage "No file names given!"
let errs=0
for filename in "${nonflags[@]}"; do
    fileage "$filename" || let errs+=1
done

exit $errs
