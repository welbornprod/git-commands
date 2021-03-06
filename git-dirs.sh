#!/bin/bash

# Finds all git repos that are in sub directories.
# Optionally, print only committed or uncommitted repos.
# -Christopher Welborn 11-28-2015
appname="git-dirs"
appversion="0.1.0"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"
# appdir="${apppath%/*}"

# Some color constants.
red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
green='\e[0;32m'
lightyellow='\e[0;33m' # shellcheck disable=SC2034
# No Color, normal/reset.
NC='\e[0m'

# Command-line arg flags/arrays
declare -a start_dirs
debug_mode=0
committed_only=0
uncommitted_only=0
pushed_only=0
unpushed_only=0
remote_only=0
nonremote_only=0
# Will quiet `print_error` and `printf_error` when set to 0.
show_errors=1
# Show current branch name beside the repo dir.
show_branch=0

function checkout {
    # git checkout, but only print errors.
    # Returns the same exit status as the git checkout command.
    local branch="$1"
    [[ -n "$branch" ]] || {
        # shellcheck disable=SC2016
        # It's not supposed to expand shellcheck, that's the point.
        print_error 'Missing `branch` argument to `checkout()`!'
        return 1
    }
    # shellcheck disable=SC2069
    # I am blocking stdout on purpose shellcheck.
    git checkout "$branch" 2>&1 >/dev/null
}

function get_changes {
    # Return success exit status if the repo has changes.
    local changes
    if ! changes="$(git stat -s)"; then
        print_error "Unable to detect changes for $dname."
        # Assume this repo has changes.
        return 0
    fi
    # Repo has changes.
    [[ -n "$changes" ]] && return 0
    # No changes.
    return 1
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

function get_remote_name {
    # Output the first remote repo name (origin, or something else.)
    local fullname
    if fullname="$(get_remote_name_full)"; then
        cut -d '/' -f 1 <<< "$fullname"
    else
        # Unable to get remote name.
        return 1
    fi
}

function get_remote_name_full {
    local rawname
    if rawname="$(git branch --color=never -r | grep -E --max-count=1 '.+/.+')"; then
        tr -d ' ' <<< "$rawname"
    else
        # No remotes.
        return 1
    fi
}

function get_unpushed {
    # Get number of unpushed commits for a repo.
    local repo="${1:-repo}"
    local branchname
    if ! branchname="$(get_current_branch)"; then
        print_error "Unable to get current branch for $repo."
        return 1
    fi
    if [[ -z "$branchname" ]]; then
        print_error "get_current_branch returned an empty string for: $repo"
        return 1
    fi

    local unpushed_msg
    if ! unpushed_msg="$(git log --pretty=oneline "@{u}..$branchname" 2>/dev/null)"; then
        # Unable to get unpushed, probably no upstream.
        print_debug "Failed to get unpushed for: $repo"
        return 1
    fi
    if [[ -z "$unpushed_msg" ]]; then
        echo "0"
    else
        wc -l <<< "$unpushed_msg"
    fi
}

function print_debug {
    # Print only if debug_mode is 1.
    (( debug_mode )) && echo -e "${green}" "$@" "${NC}"
}

function print_debug_cnt {
    # Print a label/count pair for debugging.
    local lbl
    local cnt
    local sep
    lbl="$1"
    cnt="$2"
    sep=":"
    if [[ -z "$cnt" ]]; then
        # Continuation of previous line.
        cnt=$lbl
        lbl=" "
        sep=" "
    fi
    print_debug "$(printf "%s%25s%s%s %s%s%s" "${cyan}" "$lbl" "${NC}" "$sep" "${blue}" "$cnt" "${NC}")"
}

function print_dirs {
    # Print all git dirs loaded into the git_dirs array.
    # Optionally, filtering with cmdline flags.
    local committedcnt
    local uncommittedcnt
    local errs
    local unpushed
    local unpushedcnt
    local unpushederrcnt
    local pushedcnt
    local nonremotecnt
    local skippedremotecnt
    local remotecnt
    local skippednonremotecnt
    local total
    local prevbranch=""
    local checkouterr=""

    print_debug "    Listing repos: $#"
    print_debug "   committed_only: $committed_only"
    print_debug " uncommitted_only: $uncommitted_only"
    print_debug "      pushed_only: $pushed_only"
    print_debug "    unpushed_only: $unpushed_only"
    print_debug "      remote_only: $remote_only"

    for dname in "${@}"; do
        # print_debug "Switching to directory: $dname"
        if ! cd "$dname"; then
            print_error "Unable to cd to: $dname"
            let errs+=1
            continue
        fi

        if ! prevbranch="$(get_current_branch)"; then
            print_debug "Cancelling, can't get branch name: $dname"
            continue
        fi
        if [[ -n "$use_branch" ]]; then
            # Previous branch is re-checked out later, if available.
            if ! checkouterr="$(checkout "$use_branch")"; then
                if [[ -n "$checkouterr" ]]; then
                    if [[ "$checkouterr" =~ "local changes" ]]; then
                        printf_error "%-40s %b[%blocal changes%b]\n" "$dname" "$NC" "$red" "$NC"
                    else
                        print_error "\nErrors when checking out '$use_branch' in: $dname"
                        print_error "$checkouterr"
                    fi
                fi
                print_debug "Cancelling, can't checkout branch: $dname"
                continue
            fi

        fi


        if get_remote_name_full &>/dev/null; then
            let remotecnt+=1
            if (( nonremote_only )); then
                print_debug "Skipping remote for nonremote_only: $dname"
                let skippedremotecnt+=1
                continue
            fi
        else
            let nonremotecnt+=1
            if (( remote_only )); then
                # No remote to operate on.
                print_debug "Skipping non-remote for remote_only: $dname"
                let skippednonremotecnt+=1
                continue
            fi
        fi

        # Display decisions based on committed/uncommitted status.
        if get_changes; then
            let uncommittedcnt+=1
            # Repo has changes.
            if (( committed_only )); then
                print_debug "Skipping changed repo for comitted_only: $dname"
                continue
            fi
        else
            let committedcnt+=1
            # No changes.
            if (( uncommitted_only )); then
                print_debug "Skipping unchanged repo for uncommitted_only: $dname"
                continue
            fi
        fi

        # Display decisions based on pushed/unpushed status.
        if unpushed="$(get_unpushed "$dname")"; then
            if (( unpushed > 0 )); then
                let unpushedcnt+=1
                # Repo has unpushed commits.
                if (( pushed_only )); then
                    print_debug "Skipping $unpushed unpushed commits for pushed_only: $dname"
                    continue
                fi
            else
                let pushedcnt+=1
                # Repo has all commits pushed.
                if (( unpushed_only )); then
                    print_debug "Skipping $unpushed unpushed commits for unpushed_only: $dname"
                    continue
                fi
            fi
        else
            let unpushederrcnt+=1
            # Unable to get remote info, no remote.
            if (( pushed_only )) || (( unpushed_only )); then
                print_debug "Skipping get_unpushed error repo for pushed/unpushed_only: $dname"
                continue
            fi
        fi

        # Display repo dir, with optional branch name.
        printf "%b%-50s%b" "$blue" "$dname" "$NC"

        if ((show_branch)); then
            if [[ -n "$prevbranch" ]]; then
                printf "%b%s%b" "$CYAN" "$prevbranch" "$NC"
            else
                printf_error "%s" "Unable to get branch name."
            fi
        fi
        printf "\n"
        # Run user command?
        if ((${#user_cmd_args[@]})); then
            print_debug "Running user command: ${user_cmd_args[*]}"
            eval "${user_cmd_args[@]}" || let errs+=1
        fi
        # Re-checkout previous branch?
        if [[ -n "$prevbranch" ]]; then
            if ! checkouterr="$(checkout "$prevbranch")"; then
                print_error "\nUnable to checkout previous branch '$prevbranch' in: $dname"
                [[ -n "$checkouterr" ]] && print_error "$checkouterr"
            fi
        fi
        let total+=1
    done

    print_debug
    print_debug_cnt "Committed repos" "${committedcnt:-0}"
    print_debug_cnt "Uncommitted repos" "${uncommittedcnt:-0}"
    print_debug_cnt "Remote repos" "${remotecnt:-0}"
    print_debug_cnt "Remote skipped" "${skippedremotecnt:-0}"
    print_debug_cnt "Non-remote" "${nonremotecnt:-0}"
    print_debug_cnt "Non-remote skipped" "${skippednonremotecnt:-0}"
    print_debug_cnt "Remote pushed" "${pushedcnt:-0}"
    print_debug_cnt "Remote unpushed" "${unpushedcnt:-0}"
    print_debug_cnt "Remote unpushed errors" "${unpushederrcnt:-0}"
    print_debug_cnt "Total" "$#"
    print_debug_cnt "Total printed" "${total:-0}"

    # No repos counts as an error.
    (( total > 0 )) || let errs+=1
    print_debug_cnt "Errors" "${errs:-0}"
    (( total == 0 )) && print_debug_cnt "(One of the errors was 'nothing to print'.)"
    return $errs
}

function print_error {
    # Write a msg to stderr.
    ((show_errors)) && echo -e "${RED}" "$@" "${NC}" 1>&2
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo -e "\n$1\n"
    # shellcheck disable=SC2028
    # ...the REPO_CMD example confuses shellcheck.
    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript -B
        $appscript [-b BRANCH] [-c | -C] [-l | -r] [-p | -P] [-q] [DIR...]
                   [-D] ([-- REPO_CMD])

    Options:
        DIR                    : One or more directories to look for git repos.
                                 Default: $PWD
        -- REPO_CMD            : A shell command to run inside of the repo dir.
                                 You must single quote characters such
                                 as $, ;, |,  etc.
                                 They will be evaluated after switching to the
                                 repo dir.
        -b name,--branch name  : Checkout a specific branch when checking.
                                 The branch must exist.
        -B,--showbranch        : Show which branch is selected for each repo.
        -c,--committed         : Only show repos without uncommitted changes.
        -C,--uncommitted       : Only show repos with uncommitted changes.
        -D,--debug             : Print some debugging info while running.
        -h,--help              : Show this message.
        -l,--local             : Only show repos without a remote.
        -p,--pushed            : Only show repos with all commits pushed to
                                 remote.
        -P,--unpushed          : Only show repos with commits unpushed to
                                 remote.
        -q,--quiet             : Quiet error messages.
        -r,--remote            : Only show repos with a remote.
        -v,--version           : Show $appname version and exit.

    Notes:
        -- REPO_CMD :
        REPO_CMD is a BASH command, and is evaluated after switching to
        the repo dir. If the \`cd\` command fails, nothing is done.
        You must put -- before the command.

        To git a list of modified files in uncommitted repos:
            git dirs -C -- 'echo -e \"\\n\$PWD\"; git stat | grep modified'
            * Notice the single quotes around \$PWD, ;, and |.
    "
}

function print_usage_fail {
    # Print usage message and exit with an error status.
    print_usage "$@"
    exit 1
}

function printf_error {
    # Like printf, but prints to stderr using color.
    ((show_errors)) && {
        printf "%b" "$RED"
        # shellcheck disable=SC2059
        # using all function arguments on purpose shellcheck, it's a wrapper.
        printf "$@"
        printf "%b" "$NC"
        return 0
    }
}

in_cmd_arg=0
in_branch_arg=0
use_branch=""
declare -a user_cmd_args

for arg; do
    case "$arg" in
        "-B" | "--showbranch" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                show_branch=1
            fi
            ;;
        "-b" | "--branch" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                in_branch_arg=1
            fi
            ;;
        "-c" | "--committed" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                (( ! uncommitted_only )) || print_usage_fail "-c cannot be used with -C."
                committed_only=1
            fi
            ;;
        "-C"|"--uncommitted" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                (( ! committed_only )) || print_usage_fail "-c cannot be used with -C."
                uncommitted_only=1
            fi
            ;;
        "-D"|"--debug" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                debug_mode=1
            fi
            ;;
        "-h"|"--help" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                print_usage ""
                exit 0
            fi
            ;;
        "-l"|"--local" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                nonremote_only=1
            fi
            ;;
        "-p"|"--pushed" )
            (( ! unpushed_only )) || print_usage_fail "-p cannot be used with -P."
            pushed_only=1
            ;;
        "-P"|"--unpushed" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                (( ! pushed_only )) || print_usage_fail "-p cannot be used with -P."
                unpushed_only=1
            fi
            ;;
        "-q"|"--quiet" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                show_errors=0
            fi
            ;;
        "-r"|"--remote" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                remote_only=1
            fi
            ;;
        "-v"|"--version" )
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                echo -e "$appname v. $appversion\n"
                exit 0
            fi
            ;;
        -*)
            if ((!in_cmd_arg)) && [[ "$arg" == "--" ]]; then
                in_cmd_arg=1
            elif ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            else
                print_usage_fail "Unknown flag argument: $arg"
            fi
            ;;
        *)
            if ((in_cmd_arg)); then
                user_cmd_args+=("$arg")
            elif ((in_branch_arg)); then
                use_branch="$arg"
                in_branch_arg=0
            else
                start_dirs+=("$arg")
            fi
    esac
done

if (( ${#start_dirs[@]} == 0 )); then
    start_dirs=("${start_dirs[@]}" "$PWD")
fi

let errs=0
for startdir in "${start_dirs[@]}"; do
    print_debug "Gathering repo directories in: $startdir"
    declare -a git_dirs
    while read -d $'\0' -r dname; do
        # echo "Looking at: $dname"
        # Use absolute paths for git_dirs.
        git_dirs+=("$(readlink -f "${dname%/*}")")
    done < <(find "$startdir" -type d -name ".git" -print0 | sort -z)

    print_dirs "${git_dirs[@]}"
    exitcode=${PIPE_STATUS[0]}
    (( exitcode == 0 )) || let errs+=1


done

exit $errs
