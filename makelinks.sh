#!/bin/bash

# Symlink all of these git commands to somewhere in $PATH.
# -Christopher Welborn 01-31-2016
appname="git-commands: makelinks"
appversion="0.0.1"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"
appdir="${apppath%/*}"

function confirm {
    # Confirm a user's answer to a yes/no quesion.
    [[ -n "$1" ]] && echo -e "\n$1"
    echo -e -n "\nContinue? (y/N): "
    read ans
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

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo_err "\n$1\n"

    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v

    Options:
        -d,--dryrun   : Don't install anything, just print the actions.
        -h,--help     : Show this message.
        -v,--version  : Show $appname version and exit.
    "
}

function printf_err {
    # printf to stderr.
    # shellcheck disable=SC2059
    printf "$@" 1>&2
}

function select_path {
    # Select a directory in $PATH.
    pathdirs=($(echo "$PATH" | tr ':' '\n' | sort))
    (( ${#pathdirs} > 0 )) || fail "Failed to find \$PATH directories!"
    PS3="Choose the installation path: "
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

declare -a nonflags
dryrun=0

for arg; do
    case "$arg" in
        "-d"|"--dryrun" )
            dryrun=1
            ;;
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
            nonflags=("${nonflags[@]}" "$arg")
    esac
done

# Get installation directory, make sure it's valid.
if ! bin_dir="$(select_path)"; then
    echo_err "Quitting."
    exit 2
fi
if [[ -z "$bin_dir" ]]; then
    fail "Failed to set installation directory!"
elif [[ ! -e "$bin_dir" ]]; then
    fail "Missing installation directory: $bin_dir"
elif [[ ! -w "$bin_dir" ]]; then
    fail "\nNo permissions to write to: $bin_dir\n  Do you need sudo?"
fi

gitcmds=("$appdir"/git-*.sh)
(( ${#gitcmds} > 0 )) || fail "No scripts found!: $appdir"

if ((dryrun)); then
    echo -e "\nDry run, not creating anything...\n"
else
    if ! confirm "This will install ${#gitcmds[@]} symlinks in $bin_dir/."; then
        fail "\nCancelling installation."
    fi
    echo -e "\nInstalling ${#gitcmds[@]} symlinks...\n"
fi

# Create symlinks, or report any errors that would prevent creating them.
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
    elif ((dryrun)); then
        printf "%15s %s\n" "Dry run:" "ln -s $appdir/$gitcmd $destname"
    else
        if output="$(ln -s "$gitcmd" "$destname" 2>&1)"; then
            printf "%15s %s\n" "Created:" "$destname"
        else
            printf_err "%15s %s\n%19s %s\n" "Failed:" "$destname" "Message:" "${output:-<none>}"
            let errs+=1
        fi
    fi
done

# Print a final status message.
errfmt="\nThere was %s error.\n"
(( errs != 1 )) && errfmt="\nThere were %s errors.\n"
printf_err "$errfmt" "$errs"
((! errs)) && echo "Success!"

((existing)) && echo_err "You will need to remove any existing items."
exit $errs
