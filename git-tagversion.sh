#!/bin/bash

# Shortcut to create git tags as version numbers.
# -Christopher Welborn 07-10-2015
appname="gittagversion"
appversion="0.0.1"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo -e "\n$1\n"

    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript VERSION [MESSAGE...]

    Options:
        MESSAGE       : Messages for this tag.
        VERSION       : Version number to use (in the X.X.X form).
        -h,--help     : Show this message.
        -v,--version  : Show $appname version and exit.
    "
}

function valid_version {
    # Ensure the version number matches the X.X.X pattern.
    local versionpat='^[0-9]+\.[0-9]+\.[0-9]+$'
    if [[ ! "$1" =~ $versionpat ]]; then
        echo -e "\nThis doesn't look like a version number (X.X.X): $1\n"
        local answer
        read -p "Continue? (y/N): " answer
        if [[ ! "$answer" =~ ^[Yy] ]]; then
            echo -e "\nUser cancelled.\n"
            return 1
        fi
    fi
    return 0
}
if (( $# < 1 )); then
    print_usage "Not enough arguments!"
    exit 1
fi

version=""
declare -a messages
for arg
do
    if [[ "$arg" =~ ^(-h)|(--help)$ ]]; then
        print_usage ""
        exit 0
    elif [[ "$arg" =~ ^(-v)|(--version)$ ]]; then
        echo -e "$appname v. $appversion\n"
        exit 0
    else
        if [[ -z "$version" ]]; then
            version="$arg"
        else
            messages=("${messages[@]}" "-m" "$arg")
        fi
    fi
done

valid_version "$version" || exit 1
if (( ${#messages[@]} > 2 )); then
    msgs="...$((${#messages[@]} / 2)) message paragraphs."
else
    msgs="${messages[1]-(no message yet)}"
fi
echo "Tagging at v${version}: $msgs"
git tag -a "v$version" -m "${messages[*]}"
