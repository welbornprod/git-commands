#!/bin/bash

# Set, remove, list, or search git aliases by text/regex pattern.
# -Christopher Welborn 01-15-2016

app_name="git-alias"
app_version="0.0.4"
app_path="$(readlink -f "${BASH_SOURCE[0]}")"
app_script="${app_path##*/}"
app_dir="${app_path%/*}"

colr_file="$app_dir/colr.sh"

if [[ -e "$colr_file" ]]; then
    source "$colr_file"
    colr_auto_disable
else
    logger --id=$$ "git-alias.sh: missing $colr_file"
    function colr {
        echo -e "$1"
    }
fi


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
    while read -r line; do
        cmdname="$(cut -d' ' -f1 <<<"$line")"
        cmd="$(cut -d' ' -f2- <<<"$line")"
        if [[ -z "$pat" ]]; then
            # List all
            echo -e "$(colr_alias "$cmdname" "$cmd")"
            found=1
        else
            # List matching
            if egrep "$pat" <<< "$line" &>/dev/null; then
                echo -e "$(colr_alias "$cmdname" "$cmd")"
                found=1
            fi
        fi
    done <<<"$(git "${gitargs[@]}" --get-regexp alias | sed s/alias.//)"
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
    echo -e -n "$(colr "$(printf "%-20s" "$1")" blue)"
}

function colr_cmdname {
    # Colorize command name.
    echo -e -n "$(colr "$(printf "%-20s" "$1")" green)"
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
