#!/bin/bash

# Tools for listing/removing branches.
# -Christopher Welborn 03-25-2017
appname="git-remotes"
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
    logger --id=$$ "git-remotes.sh: missing $colr_file"
    function colr {
        echo -e "$1"
    }
fi

function echo_err {
    # Echo to stderr.
    echo -e "$@" 1>&2
}

function delete_remote_branch {
    # Delete a remote branch.
    local originname=$1 branchname=$2
    [[ -z "$originname" ]] && {
        read -r -p "Enter the origin name [origin]: " originname
    }
    [[ -z "$originname" ]] && originname="origin"
    if [[ "$originname" =~ / ]]; then
        branchname="$(cut -f2 -d'/' <<<"$originname")"
        originname="$(cut -f1 -d'/' <<<"$originname")"
    fi
    local originfmt
    originfmt="$(colr "$originname" blue)"
    [[ -z "$branchname" ]] && {
        read -r -p "Enter a remote branch to delete on $originfmt: " branchname;
    }
    [[ -z "$branchname" ]] && {
        echo_err "No remote branch given!"
        return 1
    }
    local branchfmt
    branchfmt="$(colr "$branchname" cyan)"
    valid_origin_branch "$originname" "$branchname" || {
        echo_err "Not a valid remote branch: $originfmt/$branchfmt"
        return 1
    }
    echo -e "\nDeleting remote branch: $originfmt/$branchfmt"
    git push "$originname" --delete "$branchname"
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
        $appscript -b | -B
        $appscript -d [BRANCH] [ORIGIN]

    Options:
        BRANCH            : Remote branch name.
                            You may also use the 'origin/branch' format.
        ORIGIN            : Origin to work with.
        -b,--branches     : Show remote branches.
        -B,--allbranches  : Show all branches.
        -d,--delete       : Delete a remote branch.
        -h,--help         : Show this message.
        -v,--version      : Show $appname version and exit.
    "
}

function show_branches {
    # Show branches (remote by default).
    declare -a args=("$@")
    ((${#args[@]})) || args+=("-r")
    git branch "${args[@]}"
}

function show_remotes {
    # Show all remote names, using `git remote -v`, except colorized.
    local origin url method total=0 methodcolor="yellow"
    while read -r origin url method; do
        ((total++))
        methodcolor="yellow"
        [[ "$method" =~ push ]] && methodcolor="green"
        printf "%s %s %s\n" \
            "$(colr "$(printf "%-25s" "$origin")" blue)" \
            "$(colr "$(printf "%-45s" "$url")" cyan)" \
            "$(colr "$method" "$methodcolor")"

    done < <(git remote -v)

    if ((!total)); then
        echo_err "No remote repos.\n"
        return 1
    fi
    return 0
}

function valid_origin_branch {
    # Returns a successful exit status if the origin name and branch are
    # valid (tested with `git show`)
    local originname=$1 branchname=$2
    if [[ -z "$originname" ]] || [[ -z "$branchname" ]]; then
        echo_err "Both origin name and branch are needed. Got:"
        echo_err "  origin: '$originname'"
        echo_err "  branch: '$branchname'"
        return 1
    fi
    git show --no-patch --pretty="format:%h" "${originname}/${branchname}" &>/dev/null
}

declare -a nonflags
do_all_branches=0
do_branches=0
do_remote_delete=0

for arg; do
    case "$arg" in
        "-B" | "--allbranches")
            do_branches=1
            do_all_branches=1
            ;;
        "-b" | "--branches")
            do_branches=1
            ;;
        "-d" | "--delete")
            do_remote_delete=1
            ;;
        "-h" | "--help")
            print_usage ""
            exit 0
            ;;
        "-v" | "--version")
            echo -e "$appname v. $appversion\n"
            exit 0
            ;;
        -*)
            fail_usage "Unknown flag argument: $arg"
            ;;
        *)
            nonflags+=("$arg")
    esac
done

if ((do_branches)); then
    arg="-r"
    ((do_all_branches)) && arg="-a"
    show_branches "$arg"
elif ((do_remote_delete)); then
    delete_remote_branch "${nonflags[0]}" "${nonflags[1]}"
else
    show_remotes
fi
