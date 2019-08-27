#!/bin/bash

# List submodules in a repo with a nice format.
# Evolved from: git config --file .gitmodules --name-only --get-regexp path
# -Christopher Welborn 12-10-2016
appname="git-listsubmodules"
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
    logger --id=$$ "git-listsubmodules.sh: missing $colr_file"
    function colr {
        echo -e "$1"
    }
fi
shopt -s nullglob

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

function format_path {
    # Colorize the path for a submodule.
    colr "$(printf "%-35s" "$1")" "cyan"
}

function format_submodule {
    # Format/print info for a single submodule, by name.
    local name=$1
    [[ -z "$name" ]] && {
        echo_err "Missing name parameter for format_submodule!"
        return 1
    }
    pathkey="submodule.${name}.path"
    modpath="$(git config --file "$gitmodules_file" --get "$pathkey")" || return 1
    urlkey="submodule.${name}.url"
    modurl="$(git config --file "$gitmodules_file" --get "$urlkey")" || return 1
    printf "%s %s\n" "$(format_path "$modpath")" "$(format_url "$modurl")"
    return 0
}

function format_url {
    # Colorize the url for a submodule.
    colr "$1" "lightblue"
}

function get_submodule_names {
    # Print submodule names only.
    local withoutpath
    while read -r name; do
        withoutpath="${name%.path}"
        printf "%s\n" "${withoutpath#submodule.}"
    done < <(git config --file "$gitmodules_file" --name-only --get-regexp path)
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo_err "\n$1\n"

    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript [PATTERN...]

    Options:
        PATTERN       : Only list submodules with names matching PATTERN.
                        PATTERN can be a text or regex pattern.
                        The submodule name only needs to match one pattern.
        -h,--help     : Show this message.
        -v,--version  : Show $appname version and exit.
    "
}

for arg; do
    case "$arg" in
        "-h"|"--help" )
            print_usage ""
            exit 0
            ;;
        "-v"|"--version" )
            echo -e "$appname v. $appversion\n"
            exit 0
            ;;
        -*)
            fail_usage "Unknown flag argument: $arg"
            ;;
        *)
            patterns+=("$arg")
    esac
done

gitmodules_file=".gitmodules"
[[ -e "$gitmodules_file" ]] || fail "No .gitmodules found under this directory."

let errs=0
let total=0
do_all=0
((${#patterns[@]} == 0)) && do_all=1
while read -r name; do
    name_matches=0
    for userpat in "${patterns[@]}"; do
        [[ "$name" =~ $userpat ]] || continue
        name_matches=1
        break
    done
    if ((do_all)) || ((name_matches)); then
        if ! format_submodule "$name"; then
            let errs+=1
        else
            let total+=1
        fi
    fi
done < <(get_submodule_names)
# No submodules counts as an error.
if ((total == 0)); then
    errmsg="No submodules found."
    if ((${#patterns[@]})); then
        errmsg="No submodules found with patterns:"$'\n'"$(printf "    %s\n" "${patterns[@]}")"
    fi
    echo_err "$errmsg"
    let errs+=1
fi
exit $errs
