#!/bin/bash

# Git sub command to work with branches, or get branch information.
# -Christopher Welborn 05-25-2019
appname="git-branches"
appversion="0.0.2"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"
appdir="${apppath%/*}"

colr_file="$appdir/colr.sh"

if hash colrc &>/dev/null; then
    function colr {
        # Even wrapped in a function, this is still faster than colr.sh and colr.py.
        colrc "$@"
    }
elif [[ -e "$colr_file" ]]; then
    # shellcheck source=/home/cj/scripts/git-commands/colr.sh
    source "$colr_file"
    colr_auto_disable
else
    logger --id=$$ "git-branches.sh: missing $colr_file"
    function colr {
        echo -e "$1"
    }
fi

function colr_command {
    # Syntax highlight a command, the best I can using only `colr.sh`.
    local arg flag val
    local pos=0
    for arg; do
        let pos+=1
        case $pos in
            1)
                printf "%s" "$(colr "$arg" "blue" "normal" "bold")"
                ;;

            2)
                # Sub command.
                pos=2
                printf " %s" "$(colr "$arg" 31)"
                ;;
            *)
                if [[ "$arg" == -*=* ]]; then
                    # Long form flag argument.
                    flag="${arg%%=*}"
                    val="${arg##*=}"
                    printf " %s=%s" "$(colr "$flag" "cyan")" "$(colr "$val" "green")"
                elif [[ "$arg" == -* ]]; then
                    # Flag argument.
                    printf " %s" "$(colr "$arg" "cyan")"
                else
                    # Command/other argument.
                    printf " %s" "$(colr "$arg" "green")"
                fi
                ;;
        esac
    done
}

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

    local on_branch
    on_branch="$(get_current_branch)" || on_branch='<current branch>'
    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript [-D] [-a | -r]
        $appscript [-D] (-c | -C) [BRANCH] [CURRENT_BRANCH]
        $appscript [-D] -m [BRANCH]

    Options:
        BRANCH          : Branch to compare against.
                          Default: master
        CURRENT_BRANCH  : Branch to check for unmerged commits.
                          Default: $on_branch
        -a,--all        : List remote branches and local branches.
        -C,--cherry     : Show unmerged commits that are actually relevant.
        -c,--commits    : Show unmerged commits.
        -D,--debug      : Show the actual commands that are being executed.
        -h,--help       : Show this message.
        -m,--unmerged   : List unmerged branches.
        -r,--remotes    : List remote branches.
        -v,--version    : Show $appname version and exit.
    "
}

function run_cmd {
    # Run a shell command, but print what is going to run if in debug mode.
    ((debug_mode)) && printf "%s\n" "$(colr_command "$@")"
    "$@"
}

declare -a nonflags
declare -a listargs=("-v")
debug_mode=0
do_cherry=0
do_commits=0
do_list=1
do_unmerged=0
main_branch=""
cur_branch=""
for arg; do
    case "$arg" in
        "-a" | "--all")
            do_list=1
            listargs+=("--all")
            ;;
        "-C" | "--cherry")
            do_list=0
            do_commits=1
            do_cherry=1
            ;;
        "-c" | "--commits")
            do_list=0
            do_commits=1
            ;;
        "-D" | "--debug")
            debug_mode=1
            ;;
        "-h" | "--help")
            print_usage ""
            exit 0
            ;;
        "-m" | "--unmerged")
            do_list=0
            do_unmerged=1
            ;;
        "-r" | "--remotes")
            do_list=1
            listargs+=("--remotes")
            ;;
        "-v" | "--version")
            echo -e "$appname v. $appversion\n"
            exit 0
            ;;
        -*)
            fail_usage "Unknown flag argument: $arg"
            ;;
        *)
            [[ -z "$main_branch" ]] && {
                main_branch=$arg
                continue
            }
            [[ -z "$cur_branch" ]] && {
                cur_branch=$arg
                continue
            }
            nonflags+=("$arg")
    esac
done
((do_list || do_commits || do_unmerged)) || fail "No arguments."

[[ -z "$main_branch" ]] && main_branch="master"
[[ -z "$cur_branch" ]] && {
    cur_branch="$(get_current_branch)" || exit 1
}

((do_list)) && {
    # Just list branches.
    run_cmd git branch "${listargs[@]}"
}
((do_commits)) && {
    if ((do_cherry)); then
        run_cmd git cherry -v "$main_branch" "$cur_branch"
    else
        run_cmd git log "$cur_branch" --not "$main_branch" --pretty=oneline
    fi
}
((do_unmerged)) && {
    # Show unmerged branches.
    run_cmd git branch -v --no-merged "$main_branch"
}
exit
