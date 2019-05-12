#!/bin/bash

# Symlink all of these git commands to somewhere in $PATH.
# -Christopher Welborn 01-31-2016
appname="git-commands: makelinks"
appversion="0.0.1"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"
appdir="${apppath%/*}"

shopt -s nullglob

function confirm {
    # Confirm a user's answer to a yes/no quesion.
    [[ -n "$1" ]] && echo -e "\n$1"
    echo -e -n "\nContinue? (y/N): "
    read -r ans
    yespat='^[Yy]([Ee][Ss])?$'
    [[ "$ans" =~ $yespat ]] || return 1
    return 0
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

function get_install_dir {
    # Get installation directory, make sure it's valid.
    if ! bin_dir="$(select_path "Choose the installation path:")"; then
        echo_err "Quitting."
        return 2
    fi
    if [[ -z "$bin_dir" ]]; then
        fail "Failed to set installation directory!"
    elif [[ ! -e "$bin_dir" ]]; then
        fail "Missing installation directory: $bin_dir"
    elif [[ ! -w "$bin_dir" ]]; then
        fail "\nNo permissions to write to: $bin_dir\n  Do you need sudo?"
    fi
    printf "%s" "$bin_dir"
    return 0
}


function install {
    local gitcmds bin_dir new_links
    local gitcmd gitcmdbase gitcmdlnk
    local destname
    local errs existing created plural
    local errfmt linkfmt
    local output

    gitcmds=("$appdir"/git-*.{sh,py})
    (( ${#gitcmds[@]} > 0 )) || fail "No scripts found!: $appdir"
    # Get installation path.
    bin_dir="$(get_install_dir)" || return 2

    # Get new links to make, or report any errors that would prevent creating them.
    declare -A new_links
    let errs=0
    let existing=0

    for gitcmd in "${gitcmds[@]}"; do
        gitcmdbase="${gitcmd##*/}"
        gitcmdlnk="${gitcmdbase%%.*}"
        destname="$bin_dir/$gitcmdlnk"
        if [[ -z "$destname" ]]; then
            printf_err "%15s %s\n" "Name failure:" "$gitcmd"
            let errs+=1
        elif [[ -e "$destname" ]]; then
            printf_err "%15s %s\n" "Already exists:" "$destname"
            let errs+=1
            let existing+=1
        else
            new_links["$gitcmd"]="$destname"
        fi
    done
    plural="items"
    ((existing == 1)) && plural="item"
    ((existing)) && echo -e "\n$existing existing $plural will not be overwritten."
    if ((dryrun)); then
        echo -e "\nDry run, not creating anything...\n"
    else
        plural="symlinks"
        ((${#new_links[@]} == 1)) && plural="symlink"
        if ! confirm "This will install ${#new_links[@]} $plural in: $bin_dir"; then
            fail "\nCancelling installation."
        fi
        echo -e "\nInstalling ${#new_links[@]} $plural...\n"
    fi

    # Create symlinks, or report any errors that would prevent creating them.
    let created=0
    for gitcmd in "${!new_links[@]}"; do
        destname="${new_links[$gitcmd]}"
        if ((dryrun)); then
            printf "%15s %s\n" "Dry run:" "ln -s $gitcmd $destname"
        else
            if output="$(ln -s "$gitcmd" "$destname" 2>&1)"; then
                let created+=1
                printf "%15s %s\n" "Created:" "$destname"
            else
                printf_err "%15s %s\n%19s %s\n" "Failed:" "$destname" "Message:" "${output:-<none>}"
                let errs+=1
            fi
        fi
    done

    # Print a final status message.
    errfmt="\nThere were %s errors.\n"
    (( errs == 1 )) && errfmt="\nThere was %s error.\n"
    printf_err "$errfmt" "$errs"
    linkfmt="%s links were created.\n"
    (( created == 1 )) && linkfmt="%s link was created.\n"
    # shellcheck disable=SC2059
    printf "$linkfmt" "$created"
    ((! errs)) && echo "Success!"

    ((existing)) && echo_err "You will need to remove any existing items."
    return $errs
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo_err "\n$1\n"

    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript (-r | -u)

    Options:
        -d,--dryrun     : Don't install anything, just print the actions.
        -h,--help       : Show this message.
        -r,--remove     : Remove any links that were installed.
        -u,--uninstall  : Same as --remove.
        -v,--version    : Show $appname version and exit.

    With no arguments, any non-existing links will be installed.
    "
}

function printf_err {
    # printf to stderr.
    # shellcheck disable=SC2059
    printf "$@" 1>&2
}

function select_path {
    # BASH function to make the user select a directory in $PATH.
    # Outputs the path on success, returns 1 on error, and 2 when
    # no path is selected.
    # Arguments:
    #     $1 : Prompt for the select menu.
    #          Default: "Choose the installation path:"
    # Example usage:
    # if mypath="$(select_path)"; then
    #     echo "Success: $mypath"
    # else
    #     echo "No path selected."
    local pathdirs=($(printf "%s" "${PATH//:/$'\n'}" | sort))
    ((${#pathdirs} > 0)) || {
        printf "Failed to find \$PATH directories!\n" 1>&2
        return 1
    }
    PS3=$'\n'"Type \`c\` to cancel."$'\n'"${1:-Choose the installation path:} "
    local usepath
    select usepath in "${pathdirs[@]}"; do
        case "${#usepath}" in
            0 )
                return 2
                ;;
            * )
                printf "%s" "$usepath"
                break
                ;;
        esac
    done
}

function uninstall {
    local gitcmds gitcmdbase gitcmdlnk names found_links
    local dirpath possible name link errs
    declare -a names gitcmds found_links
    gitcmds=("$appdir"/git-*.{sh,py})
    (( ${#gitcmds[@]} > 0 )) || fail "No scripts found!: $appdir"
    for gitcmd in "${gitcmds[@]}"; do
        gitcmdbase="${gitcmd##*/}"
        gitcmdlnk="${gitcmdbase%%.*}"
        names+=("$gitcmdlnk")
    done

    while IFS=$'\n' read -r dirpath; do
        [[ -d "$dirpath" ]] || continue
        while IFS=$'\n' read -r possible; do
            for name in "${names[@]}"; do
                [[ "$possible" == *"$name" ]] && {
                    found_links+=("$possible")
                    break
                }
            done
        done < <(find "$dirpath" -type l -name "*git-*")
    done < <(echo "$PATH" | tr ':' '\n')

    local plural
    plural="symlinks"
    ((${#found_links[@]} == 1)) && plural="symlink"
    echo "Found ${#found_links[@]} $plural:"
    printf "    %s\n" "${found_links[@]}"
    confirm "\nThis will remove ${#found_links[@]} $plural." || fail "\nCancelling removal."

    let errs=0
    for link in "${found_links[@]}"; do
        ((dryrun)) && {
            printf "%15s %s\n" "Dry run:" "rm $link"
            continue
        }
        rm "$link" || {
            let errs+=1
            continue
        }
        printf "Removed: %s\n" "$link"
    done

    return $errs
}

declare -a nonflags
dryrun=0
do_uninstall=0

for arg; do
    case "$arg" in
        "-d"|"--dryrun" )
            dryrun=1
            ;;
        "-h"|"--help" )
            print_usage ""
            exit 0
            ;;
        "-u"|"--uninstall"|"-r"|"--remove")
            do_uninstall=1
            ;;
        "-v"|"--version" )
            echo -e "$appname v. $appversion\n"
            exit 0
            ;;
        -*)
            fail_usage "Unknown flag argument: $arg"
            ;;
        *)
            nonflags=("${nonflags[@]}" "$arg")
    esac
done

if ((do_uninstall)); then
    uninstall
else
    install
fi

exit
