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
    # shellcheck source=/home/cj/scripts/git-commands/colr.sh
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
    # Colorize a subcommand and it's path, with optional duplicate marker.
    local name=$1 cmdpath=$2 dupecnt=$3
    { [[ -n "$name" ]] && [[ -n "$cmdpath" ]]; } || {
        echo_err "Missing name/cmdpath for format_subcommand_short!"
        return 1
    }
    local namewidth=25
    if [[ -n "$dupecnt" ]]; then
        namewidth=$((namewidth - ${#name} - ${#dupecnt} - 2))
        printf "%s (%s%s: %s" \
            "$(colr "$name" "blue")" \
            "$(colr "$dupecnt" "red" "reset" "bright")" \
            "$(printf "%-*s" "$namewidth" ")")" \
            "$(colr "$cmdpath" "green")"
    else
        printf "%s: %s" \
            "$(colr "$(printf "%-*s" "$namewidth" "$name")" "blue")" \
            "$(colr "$cmdpath" "green")"
    fi
}

function get_sub_commands {
    # Lists git subcommands in PATH, with optional filtering by pattern.
    # Arguments:
    #   $1 : Filter pattern. Print only command names matching this pattern.
    local pathdir cmdpath cmdexename cmdname cmdtype dupecnt dupename
    local user_pattern=$1
    # `subcmds` is local, but `gitsubcmds` is global.
    declare -a subcmds
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
            if [[ -z "${gitsubcmds[$cmdname]}" ]]; then
                gitsubcmds[$cmdname]="$cmdpath"
                printf "%s\n" "$(format_subcommand_short "$cmdname" "$cmdpath")"
            else
                # Duplicate command.
                ((do_duplicates)) && {
                    dupecnt=2
                    dupename="${cmdname} ($dupecnt)"
                    while [[ -n "${gitsubcmds[$dupename]}" ]]; do
                        ((dupecnt++))
                        dupename="${cmdname} (${dupecnt})"
                    done
                    gitsubcmds[$dupename]="$cmdpath"
                    printf "%s\n" "$(format_subcommand_short "$cmdname" "$cmdpath" "$dupecnt")"
                }
            fi
        done
    done < <(printf "%s" "$PATH" | tr ':' '\n')
    ((${#gitsubcmds[@]})) || return 1
    return 0
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo_err "\n$1\n"

    echo "$appname v. $appversion

    Lists git subcommands and their location.

    Usage:
        $appscript -h | -v
        $appscript [-D] [-l] [PATTERN]

    Options:
        PATTERN          : Only show subcommands with a file path matching
                           PATTERN (a text or regex pattern).
        -D,--debug       : Print some debugging info while running.
        -d,--duplicates  : Show duplicate commands, that would never be
                           callable as a git subcommand due to \$PATH issues.
                           This only works when listing all commands.
        -h,--help        : Show this message.
        -l,--local       : Show local git subcommands only, not builtin.
        -v,--version     : Show $appname version and exit.
    "
}

declare -a userargs
do_local=0
do_duplicates=0
for arg; do
    case "$arg" in
        "-d"|"--duplicates" )
            do_duplicates=1
            ;;
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
get_sub_commands "$user_pattern" || {
    failmsg="."
    cmdtype=""
    ((do_local)) && cmdtype="local "
    [[ -n "$user_pattern" ]] && failmsg=" with pattern: $(colr "$user_pattern" "blue")"
    fail "No ${cmdtype}subcommands found${failmsg}"
}

cmdtype="Subcommand"
((do_local)) && cmdtype="Local subcommand"
lbl="$(colr "${cmdtype}s found" "cyan")"
[[ -n "$user_pattern" ]] &&  lbl="$lbl $(colr "with" "cyan") $(colr "$user_pattern" "yellow")"
printf "\n%s: %s\n" \
    "$lbl" \
    "$(colr "${#gitsubcmds[@]}" "blue" "reset" "bright")"
