#!/bin/bash

# ...A shortcut to: git diff-tree --no-commit-id --name-only -r COMMIT
# -Christopher Welborn 01-30-2016
app_name="git-modified"
app_ver="0.0.4"
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

function get_current_branch {
    # Output the branch name being worked on.
    local rawname
    if ! rawname="$(git branch --color=never | grep -E --only-matching '\* .+')"; then
        print_error "Unable to get branch name!"
        return 1
    else
        cut -d ' ' -f 2 <<< "$rawname"
    fi
    return 0
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo_err "\n$1\n"

    echo "$app_name v. $app_ver

    Shows modified files in a branch, commit, or unstaged changes.

    Usage:
        $app_script -h | -l | -v
        $app_script [-b name] [-l] [COMMIT...]

    Options:
        COMMIT                 : One or more commit id's to show modified files for.
        -b name,--branch name  : Use this branch.
        -h,--help              : Show this message.
        -l,--last              : Use the last commit's id.
        -v,--version           : Show $app_name version and exit.

    The default action is to show locally modified files.
    If no files have been modified, the last commit is used.
    "
}

function show_branch_files {
    # Show modified files for a specific commit.
    [[ -n "$use_branch" ]] || fail "No branch name given to show_branch_files()!"
    local cur_branch
    cur_branch="$(get_current_branch)" || return 1
    if ! output="$(git diff --no-commit-id --name-only -r "$cur_branch...$use_branch" 2>/dev/null)"; then
        echo_err "Invalid branch: $use_branch"
        return 1
    fi
    if [[ -z "$output" ]]; then
        echo_err "Failed to get info for branch: $use_branch"
        return 1
    fi
    show_commit_header "$cur_branch...$use_branch"
    local line
    IFS=$'\n'
    while read -r line; do
        echo "    $line"
    done <<<"$output"
}

function show_commit_files {
    # Show modified files for a specific commit.
    local commitid=$1
    declare -a commit_args
    [[ -n "$use_branch" ]] && commit_args+=("$use_branch")
    commit_args+=("$commitid")
    if ! output="$(git diff-tree --no-commit-id --name-only -r "${commit_args[@]}" 2>/dev/null)"; then
        echo_err "Invalid commit id: $commitid"
        return 1
    fi
    if [[ -z "$output" ]]; then
        echo_err "Failed to get info for commit: $commitid"
        return 1
    fi
    show_commit_header "$commitid"
    local line
    IFS=$'\n'
    while read -r line; do
        echo "    $line"
    done <<<"$output"
}

function show_commit_header {
    # Get commit author, subject, id.
    local commitid=$1 line commithash commitsubj commitauthor
    while read -r line; do
        commithash="$(colr "$(cut -d '~' -f 1 <<<"$line")" "blue")"
        commitsubj="$(colr "$(cut -d '~' -f 2 <<<"$line")" "cyan")"
        commitauthor="$(colr "$(cut -d '~' -f 3 <<<"$line")" "green")"
        printf "\n%s - %s (%s)" "$commithash" "$commitsubj" "$commitauthor"
        ((do_last)) && {
            printf " [last commit]"
            do_last=0
        }
    done < <(git show --format="%h~%s~%an" -s "$commitid")
    printf "\n"
}

function show_files {
    # Run a git diff command and parse the output.
    local commitid=$1
    shift
    if ! output="$("$@" 2>/dev/null)"; then
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
use_branch=""
in_branch_arg=0

for arg; do
    case "$arg" in
        "-b"|"--branch" )
            in_branch_arg=1
            ;;
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
            ((in_branch_arg)) && {
                use_branch=$arg
                in_branch_arg=0
                continue
            }
            commits=("${commits[@]}" "$arg")
    esac
done
if ((! do_last)) && ((${#commits[@]} == 0)); then
    [[ -n "$use_branch" ]] && {
        show_branch_files
        exit
    }
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
    show_commit_files "$commitid" "$use_branch" || let errs+=1
done

((errs)) && exit 1

exit
