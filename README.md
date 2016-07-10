git-commands
============

A collection of Python and Bash scripts to add functionality to `git`.

Installation:
-------------

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


Dependencies:
-------------

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


Commands:
=========

All of these commands can be invoked normally (`git-authors`), or as a
`git` subcommand (`git authors`).
There are no `man` pages for these commands, so running something like
`git authors --help` may produce weird output. You can use `git authors -h`
or `git-authors --help` instead.


git-alias
---------

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

git-authors
-----------

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

git-dirs
--------

List all sub directories that are git repos. You can optionally filter results
based on whether a repo has committed or uncommitted files, pushed or unpushed
commits, or whether a repo has a remote counterpart, or is local only.

### Usage:

```
Usage:
    git-dirs -h | -v
    git-dirs [-c | -C] [-l | -r] [-p | -P] [DIR...] [-D]

Options:
    DIR               : One or more directories to look for git repos.
                        Default: ./
    -c,--committed    : Only show repos without uncommitted changes.
    -C,--uncommitted  : Only show repos with uncommitted changes.
    -D,--debug        : Print some debugging info while running.
    -h,--help         : Show this message.
    -l,--local        : Only show repos without a remote.
    -p,--pushed       : Only show repos with all commits pushed to remote.
    -P,--unpushed     : Only show repos with commits unpushed to remote.
    -r,--remote       : Only show repos with a remote.
    -v,--version      : Show git-dirs version and exit.
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

git-filehistory
---------------

A shortcut to `git log --follow -p -- FILE`. It displays every commit where
a certain file has been modified.

### Usage:
```
Usage:
    git-filehistory -h | -v
    git-filehistory [-c] [GIT_LOG_ARGS...] FILE

Options:
    GIT_LOG_ARGS  : Any extra arguments to pass to `git log`.
    FILE          : File name to get history for.
                    Must be the last argument.
    -c,--commits  : Show commits instead of diffs.
    -h,--help     : Show this message.
    -v,--version  : Show git-filehistory version and exit.
```

git-modified
------------

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

git-pkg
-------

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

git-tagversion
--------------

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
