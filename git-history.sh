#!/bin/bash

# Shortcut to `git log --follow -p -- FILE`
# -Christopher Welborn 07-11-2015
appname="git-history"
appversion="0.1.0"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"

cyan=$'\E[0;36m'
red=$'\E[0;31m'
NC=$'\E[0m'

declare -a attr_paths=(
    ".git/info/attributes"
    ".gitattributes"
    "$HOME/.gitattributes"
)
has_attributes=0
attr_file=""
for attrpath in "${attr_paths[@]}"; do
    [[ -e "$attrpath" ]] && {
        has_attributes=1
        attr_file=$attrpath
        break
    }
done

function echo_err {
    # Echo to stderr.
    printf "%b" "$red"
    echo -e "$@" 1>&2
    printf "%b" "$NC"
}

function echo_status {
    printf "%b" "$cyan"
    echo -e "$@"
    printf "%b" "$NC"
}

function fail {
    # Print a message to stderr and exit with an error status code.
    (($#)) && echo_err "$@"
    exit 1
}

function fail_usage {
    # Print a usage failure message, and exit with an error status code.
    print_usage "$@"
    exit 1
}

function get_func_pat {
    # Build a -L arg for function names.
    # This only works on files that git knows how to diff properly.
    # .gitattributes may need to be set up for the language,
    # and .gitconfig may need a key in [core] (attributesfile) pointing
    # to that.

    # Just a normal git function pattern.
    printf ':%s:%s' "$1" "$2"
}

function get_manual_func_pat {
    # Build a regex pattern for function names.
    # Arguments:
    #   $1  : The function name, with no 'def', 'function', etc.
    #   $2  : The file name to search in.
    local cpat='\.(c|h|cpp|hpp)$'
    if [[ "$2" =~ $cpat ]]; then
        printf '/^\([a-zA-Z0-1_]\+\)\\? \\?%s \\?(/,/^\(}\|[a-zA-Z]\)/:%s' "$1" "$2"
    elif [[ "$2" == *.sh ]] || [[ "$2" == *.bash ]]; then
        printf '/\(function \)\\?\(%s {\)/,/^}/:%s' "$1" "$2"
    elif [[ "$2" == *.py ]]; then
        printf '/\(def\|class\) \(%s\)/,/^\( \+\)\\?\(def\)\|\(class\)/:%s' "$1" "$2"
    else
        printf '/\([a-z]\)\{2,8\} \(%s\)/,/\(}\)/:%s' "$1" "$2"
    fi
}

function git_diff_func {
    # Filter lines from git diff to show function changes.
    # Arguments:
    #   $1 : Function name, with no 'def', 'function', etc.
    #   $2 : Optional file name to limit search.
    local funcpat="([a-z]){3,8} ($1)"
    local greenpat=$'\x1b\[32m'
    local endpat="$greenpat[\-\+]?[\t ]+?((def )|(fn )|(function )|(}))"
    local hunkpat="@@.+"
    local apat="--- .+"
    local bpat='\+\+\+ .+'
    local line
    local in_func=0
    local last_hunk="" last_a="" last_b=""
    local found_lines
    declare -a found_lines
    ((do_debug)) && echo_status "git diff --minimal -S '$1' '$2'"
    while read -r line; do
        [[ "$line" =~ $apat ]] && last_a="$line"
        [[ "$line" =~ $bpat ]] && last_b="$line"
        [[ "$line" =~ $hunkpat ]] && last_hunk="$line"
        [[ "$line" =~ $funcpat ]] && {
            # Found func def.
            in_func=1
            found_lines+=("Found in non-committed local changes:")
            [[ -n "$last_a" ]] && found_lines+=("$last_a")
            [[ -n "$last_b" ]] && found_lines+=("$last_b")
            found_lines+=(
                "$last_hunk"
                "$line"
            )
            continue
        }
        ((in_func)) || continue
        [[ "$line" =~ $endpat ]] && {
            # Past end of func.
            echo_status "Matched end '$endpat': '$line'"
            [[ ! "$line" =~ $hunkpat ]] && found_lines+=("$line")
            break
        }
        found_lines+=("$line")
    done < <(git diff --minimal -S "$1" "$2")
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
        -D,--debug     : Show more info about what commands are executed.
        -f,--function  : View history for a specific function.
        -h,--help      : Show this message.
        -v,--version   : Show $appname version and exit.
    "
    if ((has_attributes)); then
        echo "
    Make sure \`$attr_file\` is set for your current programming languages.
    "
    else
        echo "
    You may need a \`gitattributes\` file with the appropriate language settings.

    Visit: https://git-scm.com/docs/gitattributes/#_generating_diff_text

    The basic gist is, you create a \`.gitattributes\` file with:
        *.cpp diff=cpp
        *.py diff=python

    There are many builtin languages that you can use without writing a regex
    pattern to find function names.

    Point \`.gitconfig\` at it (if you want the file to work globally):
        [core]
            attributesfile=$HOME/.gitattributes
    "
    fi
}

if [[ $# -eq 0 ]]; then
    print_usage "No arguments!"
    exit 1
fi

declare -a args
show_commits=0
in_func_arg=0
func_name=""
do_debug=0

for arg; do
    case "$arg" in
        "-D"|"--debug" )
            do_debug=1
            ;;
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
    # Try it using plain old git.
    func_pat="$(get_func_pat "$func_name" "$filename")"
    ((do_debug)) && echo_status "git log --follow -L '$func_pat' -- ."
    if ! git log --follow -L "$func_pat" -- . 2>/dev/null; then
        ((has_attributes)) && {
            echo_err "Can't find anything with '$func_pat', trying manual regex..."
        }
        manual_pat="$(get_manual_func_pat "$func_name" "$filename")"
        ((do_debug)) && echo_status "git log --follow -L '$manual_pat' -- ."
        if ! git log --follow -L "$manual_pat" -- . 2>/dev/null; then
            # May be a new function, search the diff.
            if ! git_diff_func "$func_name" "$filename"; then
                echo_err "\nNothing in \`git log\` or \`git diff\` matching '$func_name' in: $filename"
                fail "Try \`git history -S '$func_name' '$filename'\`?"
            fi
        fi
    fi
    exit
}

if ((show_commits)); then
    [[ "${args[*]}" =~ -L ]] && fail "$appname, bad arguments: -c does not work with -L."
else
    args=("${args[@]}" "-p")
fi
((do_debug)) && echo_status "git log --follow ${args[*]} -- $filename"
git log --follow "${args[@]}" -- "$filename"
