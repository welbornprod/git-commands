#!/bin/bash

# Set, remove, list, or search git aliases by text/regex pattern.
# -Christopher Welborn 01-15-2016

app_name="git-alias"
app_version="0.1.2"
app_path="$(readlink -f "${BASH_SOURCE[0]}")"
app_script="${app_path##*/}"
app_dir="${app_path%/*}"

colr_file="$app_dir/colr.sh"

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
    logger --id=$$ "$app_script: missing $colr_file"
    function colr {
        echo -e "$1"
    }
fi

cmdname_space=20
cmdname_indent="$(printf "%*s" "$((cmdname_space + 1))" " ")"

function alias_list {
    # Search or list all aliases.
    local pat=$1
    local cmdname
    local cmd
    local found=0
    local aliastype="global"
    ((do_local)) && aliastype="local"
    echo -n "Listing $aliastype git aliases"
    if [[ -z "$pat" ]]; then
        echo ":"
    else
        echo " matching '$pat':"
    fi
    while read -r -s line; do
        cmdname="$(cut -d' ' -f1 <<<"$line")"

        # Make sure this is an actual command.
        # Newlines in alias commands will wreck `read`.
        if ! cmd="$(git "${gitargs[@]}" --get "alias.$cmdname" 2>/dev/null)"; then
            continue
        fi
        # Fix any newlines that may be in the command.
        # The real newline looks ugly, the escaped newline is unescaped by
        # colr to make a real one. I don't know what else to do, except
        # at least indent the real newline so that it looks like it belongs.
        cmd="${cmd//$'\n'/\\n$cmdname_indent}"
        echo -e "$(colr_alias "$cmdname" "$cmd")"
        found=1
    done < <(git "${gitargs[@]}" --get-regexp "alias..+?$pat.+?" | sed s/alias.//)
    # Return an error exit status if nothing was found.
    (( found )) || return 1
    return 0
}

function alias_remove {
    # Remove an alias from config.
    local name=$1
    local aliastype="global"
    ((do_local)) && aliastype="local"
    if git "${gitargs[@]}" --unset "alias.${name}"; then
        echo -e "Removed $aliastype: $(colr_cmdname "$name")"
    else
        echo_err "Failed to remove: $(colr_cmdname "$name")"
    fi
}

function alias_set {
    # Set an aliases value.
    local name=$1
    local value=$2
    local aliastype="global"
    ((do_local)) && aliastype="local"
    if [[ -z "$name" ]] || [[ -z "$value" ]]; then
        echo_err "Name and value are required!"
    else
        if git "${gitargs[@]}" "alias.${name}" "$value"; then
            echo -e "Set $aliastype: $(colr_alias "$name" "$value")"
        else
            echo_err "Failed to set: $(colr_cmdname "$name")"
        fi
    fi
}

function colr_alias {
    # Colorize a command name and command.
    echo -e -n "$(colr_cmdname "$1")" "$(colr_cmd "$2")"
}

function colr_cmd {
    # Colorize command.
    echo -e -n "$(colr "$(printf "%s" "$1")" blue)"
}

function colr_cmdname {
    # Colorize command name.
    local cmdfmt
    cmdfmt="$(printf "%-*s" "$cmdname_space" "$1")"
    echo -e -n "$(colr "$cmdfmt" green)"
}

function echo_err {
    # Echo to stderr and return an error exit status.
    echo "$@" 1>&2
    return 1
}

function fail {
    # Print a message and exit the program with an error exit status.
    echo_err "$@"
    exit 1
}

function fail_usage {
    # Print a usage failure and exit the program.
    print_usage "$@"
    exit 1
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo -e "\n$1\n"

    echo "$app_name v. $app_version

    Lists git aliases.

    Usage:
        $app_script -h | -v
        $app_script [-l] [PATTERN]
        $app_script [-l] NAME VALUE
        $app_script [-l] -r NAME

    Options:
        NAME          : Name of alias for setting or removing.
        VALUE         : Value for alias.
        PATTERN       : A regex/text pattern to search for.
        -h,--help     : Show this message.
        -l,--local    : Do not use global config, use local.
        -r,--remove   : Remove an alias.
        -v,--version  : Show $app_name version and exit.
    "
}


declare -a userargs
do_remove=0
do_local=0

for arg; do
    case "$arg" in
        "-h"|"--help" )
            print_usage ""
            exit 0
            ;;
        "-l"|"--local" )
            do_local=1
            ;;
        "-r"|"--remove" )
            do_remove=1
            ;;
        "-v"|"--version" )
            echo -e "$app_name v. $app_version\n"
            exit 0
            ;;
        -*)
            fail_usage "Unknown flag argument: $arg"
            ;;
        *)
            userargs=("${userargs[@]}" "$arg")
    esac
done

if (( do_local )); then
    gitargs=("config")
else
    gitargs=("config" "--global")
fi

if (( do_remove )); then
    # Remove an alias and exit.
    (( ${#userargs[@]} == 1 )) || fail_usage "Incorrect number of arguments!"
    alias_remove "${userargs[0]}"
    exit
fi

# Listing/setting:
case ${#userargs[@]} in
    0)
        alias_list
        ;;
    1)
        alias_list "${userargs[0]}"
        ;;
    2)
        alias_set "${userargs[@]}"
        ;;
    *)
        print_usage "Too many arguments!"
        exit 1
esac
