#!/bin/bash

# Shortcut to create git tags as version numbers.
# -Christopher Welborn 07-10-2015
appname="gittagversion"
appversion="0.0.2"
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
if (( $# == 0 )); then
    print_usage "Not enough arguments!"
    exit 1
fi

version=""
declare -a messages
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
        * )
            if [[ -z "$version" ]]; then
                version="$arg"
            else
                messages=("${messages[@]}" "$arg")
            fi
            ;;
    esac
done

valid_version "$version" || exit 1
if (( ${#messages[@]} > 1 )); then
    # Tell the user how many message args they will be using.
    msgs="...$((${#messages[@]})) message paragraphs."
else
    # Tell the user what message that will be using, if one is set.
    msgs="${messages[0]-(no message yet)}"
fi
# Build message args (if any).
declare -a messageargs
for msg in "${messages[@]}"; do
    messageargs=("${messageargs[@]}" "-m" "$msg")
done

echo "Tagging at v${version}: $msgs"
git tag -a "v$version" "${messageargs[@]}"
