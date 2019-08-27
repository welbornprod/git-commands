#!/bin/bash

# ...A shortcut to: git diff-tree --no-commit-id --name-only -r COMMIT
# -Christopher Welborn 01-30-2016
app_name="git-modified"
app_ver="0.0.3"
app_path="$(readlink -f "${BASH_SOURCE[0]}")"
app_script="${app_path##*/}"
app_dir="${app_path%/*}"

colr_file="${app_dir}/colr.sh"
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

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo_err "\n$1\n"

    echo "$app_name v. $app_ver

    Usage:
        $app_script -h | -l | -v
        $app_script [-l] [COMMIT...]

    Options:
        COMMIT        : One or more commit id's to show modified files for.
        -h,--help     : Show this message.
        -l,--last     : Use the last commit's id.
        -v,--version  : Show $app_name version and exit.

    The default action is to show locally modified files.
    If no files have been modified, the last commit is used.
    "
}

function show_commit_files {
    # Show modified files for a specific commit.
    local commitid=$1
    if ! output="$(git diff-tree --no-commit-id --name-only -r "$commitid" 2>/dev/null)"; then
        echo_err "Invalid commit id: $commitid"
        return 1
    fi
    if [[ -z "$output" ]]; then
        echo_err "Failed to get info for commit: $commitid"
        return 1
    fi
    # Get commit author, subject, id.
    commitinfo="$(git show --format="%h~%s~%an" -s "$commitid")"
    commithash="$(colr "$(cut -d '~' -f 1 <<<"$commitinfo")" "blue")"
    commitsubj="$(colr "$(cut -d '~' -f 2 <<<"$commitinfo")" "cyan")"
    commitauthor="$(colr "$(cut -d '~' -f 3 <<<"$commitinfo")" "green")"
    printf "\n%s - %s (%s):\n" "$commithash" "$commitsubj" "$commitauthor"
    local line
    IFS=$'\n'
    while read -r line; do
        echo "    $line"
    done <<<"$output"
}

function show_local_files {
    # Show locally modified files.
    local line
    local output
    output="$(git diff-files --name-only)"
    [[ -n "$output" ]] || return 1
    echo -e "\n$(colr "Locally modified files" "cyan"):"
    IFS=$'\n'
    while read -r line; do
        echo "    $line"
    done <<<"$output"
}

declare -a commits
do_last=0

for arg; do
    case "$arg" in
        "-h"|"--help" )
            print_usage ""
            exit 0
            ;;
        "-l"|"--last" )
            do_last=1
            ;;
        "-v"|"--version" )
            echo -e "$app_name v. $app_ver\n"
            exit 0
            ;;
        -*)
            fail_usage "Unknown flag argument: $arg"
            ;;
        *)
            commits=("${commits[@]}" "$arg")
    esac
done
if ((! do_last)) && ((${#commits[@]} == 0)); then
    if show_local_files; then
        exit
    else
        do_last=1
    fi
fi

if ((do_last)); then
    # Use the last commit as the first commit id.
    if ! lastid="$(git last-commit -s --format="%H" 2>/dev/null)"; then
        fail "Failed to get last commit!"
    fi
    [[ -n "$lastid" ]] || fail "Failed to get last commit! (git last-commit)"
    commits=("$lastid" "${commits[@]}")
fi

let errs=0
for commitid in "${commits[@]}"; do
    show_commit_files "$commitid" || let errs+=1
done

((errs)) && exit 1

exit
