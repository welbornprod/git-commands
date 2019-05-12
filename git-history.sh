#!/bin/bash

# Shortcut to `git log --follow -p -- FILE`
# -Christopher Welborn 07-11-2015
appname="git-history"
appversion="0.0.5"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"

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

function get_func_log_pat {
    # Build a regex pattern for function names.
    # Arguments:
    #   $1  : The function name, with no 'def', 'function', etc.
    #   $2  : The file name to search in.
    printf '/\([a-z]\)\{3,8\} %s/,/\(def\|}\)/:%s' "$1" "$2"
}

function git_diff_func {
    # Filter lines from git diff to show function changes.
    # Arguments:
    #   $1 : Function name, with no 'def', 'function', etc.
    #   $2 : Optional file name to limit search.
    local funcpat="([a-z]){3,8} ($1)"
    local endpat="(def )|(fn )|(function )|(})"
    local hunkpat="@.+"
    local line
    local in_func=0
    local last_hunk=""
    local found_lines
    declare -a found_lines
    while read -r line; do
        [[ "$line" =~ $hunkpat ]] && last_hunk="$line"
        [[ "$line" =~ $funcpat ]] && {
            # Found func def.
            in_func=1
            found_lines+=(
                "Found in non-committed local changes:"
                "$last_hunk"
                "$line"
            )
            continue
        }
        ((in_func)) || continue
        [[ "$line" =~ $endpat ]] && {
            # Past end of func.
            break
        }
        found_lines+=("$line")
    done < <(git diff --minimal -G "$1" "$2")
    ((${#found_lines[@]})) || return 1

    printf "%s\n" "${found_lines[@]}"
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo -e "\n$1\n"

    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript [-c] [GIT_LOG_ARGS...] FILE
        $appscript [GIT_LOG_ARGS...] -f FUNCTION_NAME FILE

    Options:
        GIT_LOG_ARGS   : Any extra arguments to pass to \`git log\`.
        FILE           : File name to get history for, or '.' for all files.
                         Must be the last argument.
        FUNCTION_NAME  : Function name to view history for.
        -c,--commits   : Show commits instead of diffs.
        -f,--function  : View history for a specific function.
        -h,--help      : Show this message.
        -v,--version   : Show $appname version and exit.
    "
}

if [[ $# -eq 0 ]]; then
    print_usage "No arguments!"
    exit 1
fi

declare -a args
show_commits=0
in_func_arg=0
func_name=""
for arg; do
    case "$arg" in
        "-f"|"--function" )
            in_func_arg=1
            ;;
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
            if ((in_func_arg)); then
                func_name="$arg"
                in_func_arg=0
            else
                args=("${args[@]}" "$arg")
            fi
            ;;
    esac
done

filename="."
if ((${#args[@]})) && [[ -e "${args[-1]}" ]]; then
    filename="${args[-1]}"
    unset "args[-1]"
fi
[[ -n "$func_name" ]] && {
    # Doing a function search instead.
    [[ "$filename" == "." ]] && fail_usage "Must specify a full file path."
    func_pat="$(get_func_log_pat "$func_name" "$filename")"
    if ! git log --follow -L "$func_pat" -- . 2>/dev/null; then
        # May be a new function, search the diff.
        if ! git_diff_func "$func_name" "$filename"; then
            fail "Nothing in \`git log\` or \`git diff\` matching '$func_name' in: $filename"
        fi
    fi
    exit
}

if ((show_commits)); then
    [[ "${args[*]}" =~ -L ]] && fail "$appname, bad arguments: -c does not work with -L."
else
    args=("${args[@]}" "-p")
fi
# echo "Running: git log --follow ${args[@]} -- $filename"
git log --follow "${args[@]}" -- "$filename"
