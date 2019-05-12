# Git command collection

A collection of Python and Bash scripts to add functionality to `git`.

* [git-alias](#git-alias)
* [git-authors](#git-authors)
* [git-commands](#git-commands)
* [git-dirs](#git-dirs)
* [git-fileage](#git-fileage)
* [git-history](#git-history)
* [git-listsubmodules](#git-listsubmodules)
* [git-modified](#git-modified)
* [git-pkg](#git-pkg)
* [git-remotes](#git-remotes)
* [git-size-diff](#git-size-diff)
* [git-tagversion](#git-tagversion)


## Installation:

Symlink each script to somewhere in `$PATH`, with no extension. I've included
a small script (`makelinks.sh`) that will do this for you in the safest way
possible.

### makelinks.sh

This script will create symlinks to these git-commands in one of your `bin`
directories found in `$PATH`.
It will let you select a known `$PATH` directory, and confirm
the directory is okay to use before creating any symlinks. It will not
overwrite anything, and makes double sure that it is working with the correct
files/paths before doing anything.

Make sure the script is executable (`chmod +x makelinks.sh`).

You can run it like this to see what's going to happen:

```
./makelinks.sh -d
```

And then to create the symlinks just run it with no arguments:
```
./makelinks.sh
```

Make sure you have permissions to write to the directory you choose.
`sudo` may be needed if you are installing in `/usr/bin` or `/usr/local/bin`.


## Dependencies:

### colr.sh

This script is optionally sourced by some git-commands scripts. If it is found
in the same directory as the git-commands scripts it will be used. Otherwise,
the commands will have no color output, but should still function normally.

When I say *"same directory"*, I mean the same directory as the
**original script**, not the same directory as the **symlink**.

It exports a `colr` function, and a map of colr/style names to escape codes
(`fore`, `back`, `style`).

You can run `./colr.sh --help` to see how this might be used as a command
line utility.

The latest version of `colr.sh` is available at
[github.com/welbornprod/colr.sh](https://github.com/welbornprod/colr.sh)

# Commands:

All of these commands can be invoked normally (`git-authors`), or as a
`git` subcommand (`git authors`).
There are no `man` pages for these commands, so running something like
`git authors --help` may produce weird output. You can use `git authors -h`
or `git-authors --help` instead.


## git-alias

Replacement for `git-alias` from the `git-extras` package. It provides color
output when listing aliases. You can also list both global and local aliases
by matching against a text or regex pattern.

### Usage:
```
Usage:
     git-alias -h | -v
     git-alias [-l] [PATTERN]
     git-alias [-l] NAME VALUE
     git-alias [-l] -r NAME

Options:
     NAME          : Name of alias for setting or removing.
     VALUE         : Value for alias.
     PATTERN       : A regex/text pattern to search for.
     -h,--help     : Show this message.
     -l,--local    : Do not use global config, use local.
     -r,--remove   : Remove an alias.
     -v,--version  : Show git-alias version and exit.
```

#### List aliases:

```
git alias
```

#### List local aliases:
```
git alias -l
```

#### Search for aliases:
```
git alias whatever
```

#### Set an alias:
```
git alias mything '!echo "okay"'
```

#### Remove an alias:
```
git alias -r mything
```

## git-authors

Lists all authors (with email addresses) from all commits in a repo.

### Usage:

```
Usage:
    git-authors [-h | -v]
    git-authors [DIR]

Options:
    DIR           : Repo directory to use.
    -h,--help     : Show this help message.
    -v,--version  : Show git-authors version and exit.
```

## git-commands

List all git subcommands that can be used, optionally filtering by local/system
command or by text/regex pattern.

### Usage:
```
Usage:
    git-commands -h | -v
    git-commands [-D] [-l] [PATTERN]

Options:
    PATTERN          : Only show subcommands with a file path matching
                       PATTERN (a text or regex pattern).
    -D,--debug       : Print some debugging info while running.
    -d,--duplicates  : Show duplicate command names.
    -h,--help        : Show this message.
    -l,--local       : Show local git subcommands only, not builtin.
    -v,--version     : Show git-commands version and exit.
```

## git-dirs

List all sub directories that are git repos. You can optionally filter results
based on whether a repo has committed or uncommitted files, pushed or unpushed
commits, or whether a repo has a remote counterpart, or is local only.

### Usage:

```
    Usage:
        git-dirs -h | -v
        git-dirs [-b BRANCH] [-c | -C] [-l | -r] [-p | -P]
                 [-q] [DIR...] [-D] ([-- REPO_CMD])

    Options:
        DIR                    : One or more directories to look for git repos.
                                 Default: /home/cj/scripts/git-commands
        -- REPO_CMD            : A shell command to run inside of the repo dir.
                                 You must single quote characters such
                                 as $, ;, |,  etc.
                                 They will be evaluated after switching to the
                                 repo dir.
        -b name,--branch name  : Checkout a specific branch when checking.
                                 The branch must exist.
        -c,--committed         : Only show repos without uncommitted changes.
        -C,--uncommitted       : Only show repos with uncommitted changes.
        -D,--debug             : Print some debugging info while running.
        -h,--help              : Show this message.
        -l,--local             : Only show repos without a remote.
        -p,--pushed            : Only show repos with all commits pushed to
                                 remote.
        -P,--unpushed          : Only show repos with commits unpushed to
                                 remote.
        -q,--quiet             : Quiet error messages.
        -r,--remote            : Only show repos with a remote.
        -v,--version           : Show git-dirs version and exit.

    Notes:
        -- REPO_CMD :
        REPO_CMD is a BASH command, and is evaluated after switching to
        the repo dir. If the `cd` command fails, nothing is done.
        You must put -- before the command.

        To git a list of modified files in uncommitted repos:
            git dirs -C -- 'echo -e "\n$PWD"; git stat | grep modified'
            * Notice the single quotes around $PWD, ;, and |.
```

#### Show all repos with unpushed commits to remote:
```
git dirs -P
```

#### Show all local repos with uncommitted changes:
```
git dirs -l -C
```

...you get the idea.

## git-fileage

Shows the age of a file in the repo, or shows the very first commit info.
There may be more than one "first" commit, if histories were merged.

### Usage:
```
Usage:
    git-fileage -h | -v
    git-fileage -f | -F [GIT_SHOW_ARGS...]
    git-fileage [-t] [-z] FILE...

Options:
    FILE             : One or more file names to get the initial commit
                       date for.
    GIT_SHOW_ARGS    : Extra arguments for `git show <commit_id>`.
    -F,--firstfull   : Show the first commit(s), with full diff.
    -f,--first       : Alias for `git-fileage -F --no-patch`.
                       Only the commit header is shown, not the diff.
    -h,--help        : Show this message.
    -t,--timestamp   : Use the raw timestamp.
    -v,--version     : Show git-fileage version and exit.
    -z,--timezone    : Show the committer timezone also.

```

## git-history

A shortcut to `git log --follow -p -- FILE`. It displays every commit where
a certain file has been modified.

### Usage:
```
    Usage:
        git-history.sh -h | -v
        git-history.sh [-c] [GIT_LOG_ARGS...] FILE
        git-history.sh [GIT_LOG_ARGS...] -f FUNCTION FILE

    Options:
        GIT_LOG_ARGS   : Any extra arguments to pass to `git log`.
        FILE           : File name to get history for, or '.' for all files.
                         Must be the last argument.
        FUNCTION       : Function name to view history for.
        -c,--commits   : Show commits instead of diffs.
        -f,--function  : View history for a specific function.
        -h,--help      : Show this message.
        -v,--version   : Show git-filehistory version and exit.
```

## git-listsubmodules

List submodule paths and urls for a repo.

### Usage:
```
Usage:
     git-listsubmodules -h | -v
     git-listsubmodules [PATTERN...]

 Options:
     PATTERN       : Only list submodules with names matching PATTERN.
                     PATTERN can be a text or regex pattern.
                     The submodule name only needs to match one pattern.
     -h,--help     : Show this message.
     -v,--version  : Show git-listsubmodules version and exit.
```

## git-modified

A mixture of `git stat` and `git diff-tree`. If there are local changes in
the repo, this command will list all files that were modified. With no
local changes, it will list all files modified in the last commit. You can
also list modified files for one or more commit ids.

### Usage:
```
Usage:
    git-modified -h | -l | -v
    git-modified [-l] [COMMIT...]

Options:
    COMMIT        : One or more commit id's to show modified files for.
    -h,--help     : Show this message.
    -l,--last     : Use the last commit's id.
    -v,--version  : Show git-modified version and exit.

The default action is to show locally modified files.
If no files have been modified, the last commit is used.
```

## git-pkg

Like `git-archive`, this creates a `.tar.gz` file from a git repo.

### Usage:
```
Usage:
    git-pkg -h | -v
    git-pkg FILE [REPO] [-e excludepattern] [-i includepattern] [-d]
    git-pkg -l [-e excludepattern] [-i includepattern] [REPO]


Options:
    FILE                  : Resulting package name.
                            '.tar.gz' is appended if not given.
    REPO                  : Directory for git repo.
                            Default: ./
    -d,--dryrun           : Show what would've been added,
                            don't create a package.
    -e pat,--exclude pat  : Regex or text for filtering,
                            if found in a file name the file is excluded.
    -i pat,--include pat  : Regex or text for filtering,
                            if found in a file name the file is included,
                            otherwise the file is excluded.
                            The exclude flag overrides this.
    -h,--help             : Show this message.
    -l,--list             : List files that would be packaged.
    -v,--version          : Show version.
```

## git-remotes

List remote urls, branches, and delete remote branches.

### Usage:
```
Usage:
    git-remotes -h | -v
    git-remotes -b | -B
    git-remotes -d [BRANCH] [ORIGIN]

Options:
    BRANCH            : Remote branch name.
                        You may also use the 'origin/branch' format.
    ORIGIN            : Origin to work with.
    -b,--branches     : Show remote branches.
    -B,--allbranches  : Show all branches.
    -d,--delete       : Delete a remote branch.
    -h,--help         : Show this message.
    -v,--version      : Show git-remotes version and exit.
```

## git-size-diff

Compare file sizes between branches/trees with `diff-tree`, or check file
sizes based on `diff-index`. The output is formatted with colors, and for
`diff-tree` the size changes are shown.

### Usage:
```
Usage:
    git-size-diff -h | -v
    git-size-diff [-D] DIFF_TREE_ARGS...
    git-size-diff [-D] -c [DIFF_INDEX_ARGS...] TREEISH [PATH...]

Options:
    DIFF_TREE_ARGS   : Branches, or other options for `diff-tree`.
    DIFF_INDEX_ARGS  : Extra options for `diff-index`.
    TREEISH          : Tree-like arg for `diff-index`.
    PATH             : Extra path option for `diff-index`.
    -c,--cached      : Use local cached information.
    -D,--debug       : Debug mode, print some more info.
    -h,--help        : Show this message.
    -v,--version     : Show git-size-diff version and exit.
```

## git-tagversion

A shortcut to `git tag -a`, specifically for making version tags (`vX.X.X`).

### Usage:
```
Usage:
    git-tagversion -h | -v
    git-tagversion VERSION [MESSAGE...]

Options:
    MESSAGE       : Messages for this tag.
    VERSION       : Version number to use (in the X.X.X form).
    -h,--help     : Show this message.
    -v,--version  : Show git-tagversion version and exit.
```
