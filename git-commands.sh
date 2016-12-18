#!/bin/bash

# Lists git subcommands.
# -Christopher Welborn 12-17-2016
appname="git-commands"
appversion="0.0.1"
apppath="$(readlink -f "${BASH_SOURCE[0]}")"
appscript="${apppath##*/}"
appdir="${apppath%/*}"
colr_file="$appdir/colr.sh"

if [[ -e "$colr_file" ]]; then
    source "$colr_file"
    colr_auto_disable
else
    logger --id=$$ "git-commands.sh: missing $colr_file"
    function colr {
        echo -e "$1"
    }
fi

# Can be set with --debug
debug_mode=0

shopt -s nullglob

function debug {
    # Echo a debug message to stderr if debug_mode is set.
    ((debug_mode)) && echo_err "$@"
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

function format_subcommand_short {
    # Colorize a subcommand and it's path.
    local name=$1 cmdpath=$2
    { [[ -n "$name" ]] && [[ -n "$cmdpath" ]]; } || {
        echo_err "Missing name/cmdpath for format_subcommand_short!"
        return 1
    }
    printf "%s: %s" \
        "$(colr "$(printf "%-25s" "$name")" "blue")" \
        "$(colr "$cmdpath" "green")"
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo_err "\n$1\n"

    echo "$appname v. $appversion

    Usage:
        $appscript -h | -v
        $appscript [-D] [-l] [PATTERN]

    Options:
        PATTERN       : Only show subcommands with a file path matching
                        PATTERN (a text or regex pattern).
        -D,--debug    : Print some debugging info while running.
        -h,--help     : Show this message.
        -l,--local    : Show local git subcommands only, no system commands.
        -v,--version  : Show $appname version and exit.
    "
}

declare -a userargs
do_local=0
for arg; do
    case "$arg" in
        "-D"|"--debug" )
            debug_mode=1
            ;;
        "-h"|"--help" )
            print_usage ""
            exit 0
            ;;
        "-l"|"--local" )
            do_local=1
            ;;
        "-v"|"--version" )
            echo -e "$appname v. $appversion\n"
            exit 0
            ;;
        -*)
            fail_usage "Unknown flag argument: $arg"
            ;;
        *)
            userargs+=("$arg")
    esac
done

user_pattern=""
((${#userargs[@]})) && user_pattern="${userargs[0]}"

declare -A gitsubcmds
while IFS=$'\n' read -r pathdir; do
    subcmds=("$pathdir"/git-*)
    for cmdpath in "${subcmds[@]}"; do
        if ((do_local)) && [[ "$cmdpath" != /home/* ]]; then
            debug "Skipping non-local command: $cmdpath"
            continue
        fi
        # Ignore commands that don't match the pattern, when given.
        if [[ -n "$user_pattern" ]] && [[ ! "$cmdpath" =~ $user_pattern ]]; then
            debug "Skipping non-matching command: $cmdpath"
            continue
        fi
        cmdexename="${cmdpath##*/}"
        cmdname="${cmdexename##git-}"

        # Ignore duplicate command names, and go by $PATH.
        [[ -z "${gitsubcmds[$cmdname]}" ]] && gitsubcmds[$cmdname]="$cmdpath"
        printf "%s\n" "$(format_subcommand_short "$cmdname" "$cmdpath")"
    done
done < <(printf "%s" "$PATH" | tr ':' '\n')

cmdtype="Subcommand"
((do_local)) && cmdtype="Local subcommand"
lbl="$(colr "${cmdtype}s found" "cyan")"
[[ -n "$user_pattern" ]] &&  lbl="$lbl $(colr "with" "cyan") $(colr "$user_pattern" "yellow")"
printf "\n%s: %s\n" \
    "$lbl" \
    "$(colr "${#gitsubcmds[@]}" "blue" "reset" "bright")"

let exitcode=0
((${#gitsubcmds[@]} > 0)) || exitcode=1

exit $exitcode
