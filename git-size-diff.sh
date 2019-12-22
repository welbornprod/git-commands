#!/bin/bash

# ...Get file size differences for branches.
# Original script from: http://stackoverflow.com/a/10847242
# Heavily modified for colors, clarity, etc.
# -Christopher Welborn 02-01-2017
appname="git-size-diff"
appversion="0.0.2"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"
appdir="${apppath%/*}"
colr_file="$appdir/colr.sh"
using_colrc=0

if hash colrc &>/dev/null; then
    using_colrc=1
    function colr {
        # Even wrapped in a function, this is still faster than colr.sh and colr.py.
        colrc "$@"
    }
elif [[ -e "$colr_file" ]]; then
    # shellcheck source=/home/cj/scripts/git-commands/colr.sh
    source "$colr_file"
    colr_auto_disable
else
    logger --id=$$ "git-size-diff.sh: missing $colr_file"
    function colr {
        echo -e "$1"
    }
fi

function debug {
    # Like echo_err, but only if debug_mode is truthy.
    ((debug_mode)) && echo -e "$(colr "$*" "green")" 1>&2
}
function echo_err {
    # Echo to stderr.
    echo -e "$(colr "$*" "red")" 1>&2
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

    Show file size changes between two branches/revisions with \`diff-tree\`,
    or show file sizes based on \`diff-index\`.

    Usage:
        $appscript -h | -v
        $appscript [-D] DIFF_TREE_ARGS...
        $appscript [-D] -c [DIFF_INDEX_ARGS...] TREEISH [PATH...]

    Options:
        DIFF_TREE_ARGS   : Branches, or other options for \`diff-tree\`.
        DIFF_INDEX_ARGS  : Extra options for \`diff-index\`.
        TREEISH          : Tree-like arg for \`diff-index\`.
        PATH             : Extra path option for \`diff-index\`.
        -c,--cached      : Use local cached information.
        -D,--debug       : Debug mode, print some more info.
        -h,--help        : Show this message.
        -v,--version     : Show $appname version and exit.
    "
}

(( $# > 0 )) || fail_usage "No arguments!"

declare -a revlistargs
do_cached=0
debug_mode=0

for arg; do
    case "$arg" in
        "-c" | "--cached")
            do_cached=1
            ;;
        "-D" | "--debug")
            debug_mode=1
            ;;
        "-h" | "--help")
            print_usage ""
            exit 0
            ;;
        "-v" | "--version")
            echo -e "$appname v. $appversion\n"
            exit 0
            ;;
        -*)
            fail_usage "Unknown flag argument: $arg"
            ;;
        *)
            revlistargs+=("$arg")
    esac
done
((${#revlistargs[@]} == 0)) && fail_usage "No arguments!"

debug "Sourcing git-sh-setup."
# shellcheck source=/usr/lib/git-core/git-sh-setup
source "$(git --exec-path)/git-sh-setup"
declare -a gitcmdargs=($(git rev-parse --sq "${revlistargs[@]}"))

cmd="diff-tree -r"
if ((do_cached)); then
    cmd="diff-index"
    if ((${#gitcmdargs[@]} > 1)); then
        # Ensure -- to seperate paths.
        gitcmdargs=("${gitcmdargs[0]}" "--" "${gitcmdargs[@]:1}")
    fi
fi

gitcmd="git $cmd ${gitcmdargs[*]}"
debug "Running: $gitcmd"
# Using `eval` because of the output from git rev-parse.
if ! gitoutput=$(eval "$gitcmd"); then
    echo_err "Command failed: $gitcmd"
    exit 1
fi
if [[ -z "$gitoutput" ]]; then
    printf "\n%s\n" "$(colr "No changes." "green")"
    exit 0
fi

total=0
while read -r srcmode dstmode srcsha1 dstsha1 status srcpath dstpath; do
    # Known statuses (I only need M, A, and D for size changes. Maybe T?):
    # A: addition of a file
    # C: copy of a file into a new one
    # D: deletion of a file
    # M: modification of the contents or mode of a file
    # R: renaming of a file
    # T: change in the type of the file
    # U: file is unmerged (you must complete the merge before it can be committed)
    # X: "unknown" change type (most probably a bug, please report it)
    case "$status" in
        M)
            pathcolor="yellow"
            if ! srcbytes=$(git cat-file -s "$srcsha1" 2>/dev/null); then
                srcbytes=0
                echo_err "cat-file failed for src sha1: $srcpath ($srcsha1)"
            fi

            if ! dstbytes=$(git cat-file -s "$dstsha1" 2>/dev/null); then
                dstbytes=0
                if [[ "$dstsha1" ==  "0000000000000000000000000000000000000000" ]]; then
                    # Deleted or unmerged.
                    echo_err "Deleted/unmerged dest. path: $srcpath"
                else
                    echo_err "cat-file failed for dst sha1: $dstpath ($dstsha1)"
                fi
            fi

            bytes=$((dstbytes - srcbytes))
            ;;
        A)
            pathcolor="green"
            if ! bytes=$(git cat-file -s "$dstsha1" 2>/dev/null); then
                bytes=0
                echo_err "cat-file failed for: $dstsha1"
            fi
            ;;
        D)
            pathcolor="red"
            if ! bytes=-$(git cat-file -s "$srcsha1" 2>/dev/null); then
                bytes=0
                echo_err "cat-file failed for: $dstsha1"
            fi
            ;;
        *)
            [[ -n "$status" ]] && printf "Warning: unhandled mode %s in:
    Source Mode: %s
     Dest. Mode: %s
    Source SHA1: %s
     Dest. SHA1: %s
         Status: %s
    Source Path: %s
     Dest. Path: %s\n" \
                "$status" \
                "$srcmode" \
                "$dstmode" \
                "$srcsha1" \
                "$dstsha1" \
                "$status" \
                "$srcpath" \
                "$dstpath"
            continue
            ;;
    esac
    total=$((total + bytes))
    bytescolor="lightblue"
    if ((bytes == 0)); then
        bytescolor="lightmagenta"
    elif ((bytes < 0)); then
        bytescolor="cyan"
    fi

    printf '%s %s %s\n' \
        "$(colr "$(printf "%10s" "$bytes")" "$bytescolor")" \
        "$(colr "$status" "$pathcolor" "reset" "bright")" \
        "$(colr "$srcpath" "$pathcolor")"
done <<<"$gitoutput"

totalcolor="red"
((total < 1)) && totalcolor="green"
if ((total < 0)) && ((using_colrc)); then
    total="\\$total"
fi
printf "\nTotal: %s\n" "$(colr "$total" "$totalcolor" "reset" "bright")"

