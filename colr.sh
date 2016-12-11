#!/bin/bash

# Bash color function to colorize text by name, instead of number.
# Also includes maps from name to escape code for fore, back, and styles.
# -Christopher Welborn 08-27-2015

# Variables are namespaced to not interfere when sourced.
colr_app_name="Colr"
colr_app_version="0.1.0"
colr_app_path="$(readlink -f "${BASH_SOURCE[0]}")"
colr_app_script="${colr_app_path##*/}"

# This flag can be set with colr_enable or colr_disable.
colr_disabled=0

# Functions to format a color number into an actual escape code.
function codeformat {
    # Basic fore, back, and styles.
    printf "\033[%sm" "$1"
}
function extforeformat {
    # 256 fore color
    printf "\033[38;5;%sm" "$1"
}
function extbackformat {
    # 256 back color
    printf "\033[48;5;%sm" "$1"
}

# Maps from color/style name -> escape code.
declare -A fore back style

function build_maps {
    # Build the fore/back maps.
    # Names and corresponding base code number
    local colornum
    # shellcheck disable=SC2102
    declare -A colornum=(
        [black]=0
        [red]=1
        [green]=2
        [yellow]=3
        [blue]=4
        [magenta]=5
        [cyan]=6
        [white]=7
        )
    local cname
    for cname in "${!colornum[@]}"; do
        fore[$cname]="$(codeformat $((30 + ${colornum[$cname]})))"
        fore[light$cname]="$(codeformat $((90 + ${colornum[$cname]})))"
        back[$cname]="$(codeformat $((40 + ${colornum[$cname]})))"
        back[light$cname]="$(codeformat $((100 + ${colornum[$cname]})))"
    done
    # shellcheck disable=SC2154
    fore[reset]="$(codeformat 39)"
    back[reset]="$(codeformat 49)"

    # 256 colors.
    local cnum
    for cnum in {0..255}; do
        fore[$cnum]="$(extforeformat "$cnum")"
        back[$cnum]="$(extbackformat "$cnum")"
    done

    # Map of base code -> style name
    local stylenum
    # shellcheck disable=SC2102
    declare -A stylenum=(
        [reset]=0
        [bright]=1
        [dim]=2
        [italic]=3
        [underline]=4
        [flash]=5
        [highlight]=7
        [normal]=22
    )
    local sname
    for sname in "${!stylenum[@]}"; do
        style[$sname]="$(codeformat "${stylenum[$sname]}")"
    done
}
build_maps

function colr {
    # Colorize a string.
    local text="$1"
    if ((colr_disabled)); then
        # Color has been globally disabled.
        echo -en "$text"
        return
    fi

    local forecolr="${2:-reset}"
    local backcolr="${3:-reset}"
    local stylename="${4:-normal}"

    declare -a codes resetcodes
    if [[ "$stylename" =~ ^reset ]]; then
        resetcodes=("${style[$stylename]}" "${resetcodes[@]}")
    else
        codes=("${codes[@]}" "${style[$stylename]}")
    fi

    if [[ "$backcolr" =~ reset ]]; then
        resetcodes=("${back[$backcolr]}" "${resetcodes[@]}")
    else
        codes=("${codes[@]}" "${back[$backcolr]}")
    fi

    if [[ "$forecolr" =~ reset ]]; then
        resetcodes=("${fore[$forecolr]}" "${resetcodes[@]}")
    else
        codes=("${codes[@]}" "${fore[$forecolr]}")
    fi

    # Reset codes must come first (style reset can affect colors)
    local rc
    for rc in "${resetcodes[@]}"; do
        echo -en "$rc"
    done
    local c
    for c in "${codes[@]}"; do
        echo -en "$c"
    done
    local closing="\033[m"

    echo -n "$text"
    echo -en "$closing"
}

function colr_auto_disable {
    # Auto disable colors if stdout is not a tty,
    # or if the user supplied file descriptors are not ttys.
    # Arguments:
    #  $@ : One or more TTY numbers to check.
    #       Default: 1

    if (($# == 0)); then
        # Just check stdout by default.
        [[ -t "${1:-1}" ]] || colr_disabled=1
        return
    fi
    # Make sure all user's tty args are ttys.
    local ttynum
    for ttynum in "$@"; do
        if [[ ! -t "$ttynum" ]]; then
            colr_disabled=1
            break
        fi
    done
}

function colr_enable {
    # Re-enable colors after colr_disable has been called.
    colr_disabled=0
}

function colr_disable {
    # Disable colors for the `colr` function.
    colr_disabled=1
}

function print_usage {
    # Show usage reason if first arg is available.
    [[ -n "$1" ]] && echo -e "\n$1\n"

    echo "${fore[blue]}${style[bright]}$colr_app_name v. $colr_app_version${style[reset]}

    Usage:${fore[magenta]}
        $colr_app_script -h | -v
        $colr_app_script TEXT FORE [BACK] [STYLE]
    ${style[reset]}
    Options:${fore[green]}
        BACK          : Name of back color for the text.
        FORE          : Name of fore color for the text.
        STYLE         : Name of style for the text.
        TEXT          : Text to colorize.
        -h,--help     : Show this message.
        -v,--version  : Show $colr_app_name version and exit.
    ${style[reset]}
    "
}


export colr
export fore
export back
export style

if [[ "$0" == "$BASH_SOURCE" ]]; then
    declare -a userargs
    do_forced=0
    for arg; do
        case "$arg" in
            "-f"|"--force" )
                do_forced=1
                ;;
            "-h"|"--help" )
                print_usage ""
                exit 0
                ;;
            "-v"|"--version" )
                echo -e "$colr_app_name v. $colr_app_version\n"
                exit 0
                ;;
            -*)
                print_usage "Unknown flag argument: $arg"
                exit 1
                ;;
            *)
                userargs=("${userargs[@]}" "$arg")
        esac
    done

    # Script was executed.
    # Automatically disable colors if stdout is not a tty, unless forced.
    ((do_forced)) || colr_auto_disable 1
    colr "${userargs[@]}"
fi
