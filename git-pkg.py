#!/usr/bin/env python3
# -*- coding: utf-8 -*-

""" GitPkg
    Makes a tar.gz file out of a git repo/branch.
    I wrote this before I found out about git-archive.
    -Christopher Welborn
"""


import os
import re
import subprocess
import sys
import tarfile

from docopt import docopt

NAME = 'GitPkg'
VERSION = '1.0.1'
VERSIONSTR = '{} v. {}'.format(NAME, VERSION)
SCRIPT = os.path.split(sys.argv[0])[1]
CWD = os.getcwd()
USAGESTR = """{verstr}
    Creates a tar.gz package out of all files found with `git ls-files`,
    including relative paths.

    Usage:
        {script} -h | -v
        {script} FILE [REPO] [-e excludepattern] [-i includepattern] [-d]
        {script} -l [-e excludepattern] [-i includepattern] [REPO]


    Options:
        FILE                  : Resulting package name.
                                '.tar.gz' is appended if not given.
        REPO                  : Directory for git repo.
                                Default: {cwd}
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
""".format(verstr=VERSIONSTR, script=SCRIPT, cwd=CWD)


def main(argd):
    """ Main entry-point, expects docopt arg dict. """
    # Set working repo directory and outfile.
    repodir = argd['REPO'] or os.getcwd()
    filename = argd['FILE']

    if filename:
        # Ensure file ends with tar.gz
        if not filename.endswith(('.tar.gz', '.tgz', '.targz')):
            filename = '{}.tar.gz'.format(filename)
        # Check for existing filename.
        if confirm_overwrite(filename):
            # Create package.
            return do_package(repodir,
                              filename,
                              excludestr=argd['--exclude'],
                              includestr=argd['--include'],
                              dryrun=argd['--dryrun'])
        else:
            # Don't overwrite existing package.
            print('\nUser Cancelled.\n')
            return 1

    elif argd['--list']:
        # List files only.
        return do_list(repodir,
                       excludestr=argd['--exclude'],
                       includestr=argd['--include'])


def confirm_overwrite(filename):
    """ Simple inputbox to ask the user if a file should be clobbered.
        Returns True for 'yes, overwrite' or False for 'No don't do it.'
    """
    # Confirm overwriting existing files...
    if os.path.exists(filename):
        print('\nThis file exists already!: {}'.format(filename))
        overwrite = input('\nOverwrite file? (y/n): ')
        return overwrite.lower()[0] == 'y'
    # File doesn't exist (True means it will be written)
    return True


def do_list(sdir, excludestr=None, includestr=None):
    """ Just list the files, don't package them. """

    try:
        gitfiles = get_files(sdir,
                             excludestr=excludestr,
                             includestr=includestr)
    except InvalidRepo as exinvalid:
        print('\nInvalid git repo: {}\n'.format(exinvalid))
        return 1
    except InvalidRegex:
        return 1

    if not gitfiles:
        print('\nNo files found in: {}\n'.format(sdir))
        return 1

    # Have valid files.
    filelen = len(gitfiles)
    print('\nListing {} files in: {}\n'.format(filelen, sdir))
    print('    {}'.format('\n    '.join(gitfiles)))
    print('\nFound {} files in: {}\n'.format(filelen, sdir))
    return 0


def do_package(sdir, filename, excludestr=None, includestr=None, dryrun=False):
    """ Create a tar.gz file from a git repo.
        If dryrun is True, no file will be created.
    """

    print('\nRetrieving file names from git repo: {}'.format(sdir))
    try:
        gitfiles = get_files(sdir,
                             excludestr=excludestr,
                             includestr=includestr,
                             relativepaths=True)
    except InvalidRepo as exinvalid:
        print('\nInvalid git repo: {}'.format(exinvalid))
        return 1
    except InvalidRegex:
        return 1

    if not gitfiles:
        print('\nNo files found in: {}'.format(sdir))
        return 1

    # Create tar file.
    print('\nCreating package: {}'.format(filename))
    if not dryrun:
        newtar = tarfile.TarFile.open(name=filename, mode='w|gz')

    print('\nAdding files...')
    # Figure out base dir for tar archive. (arcname)
    arcbase = sdir[:-1] if sdir.endswith('/') else sdir
    arcbase = os.path.split(arcbase)[1]

    for relname in gitfiles:
        fullname = os.path.join(sdir, relname)
        print_op('adding', fullname)

        arcname = get_arcname(arcbase, relname)
        try:
            if dryrun:
                print_op('added', '{}\n'.format(arcname))
            else:
                newtar.add(fullname, arcname=arcname)
        except Exception as exadd:
            print('\nError adding file: {}\n{}\n'.format(fullname, exadd))

    # Finished. Close (save) tar file.
    if dryrun:
        print('\nDry run, no package created.')
    else:
        newtar.close()
        print('\nPackage created: {}'.format(filename))
    return 0


def get_arcname(arcbase, relname):
    """ Joins the arcbase and relname so the packages have 1 toplevel dir. """

    if relname.startswith('/'):
        relname = relname[1:]
    return os.path.join(arcbase, relname)


def get_files(sdir, excludestr=None, includestr=None, relativepaths=False):
    """ Get files included in a git repo. """

    # validate/compile regex pattern if used
    try:
        excludepat = re.compile(excludestr) if excludestr else None
    except Exception as ex:
        print('\nError in exclude pattern: {}\nMessage: {}'.format(excludestr,
                                                                   ex))
        raise InvalidRegex('Invalid regex: {}'.format(excludestr))
    try:
        includepat = re.compile(includestr) if includestr else None
    except Exception as ex:
        print('\nError in include pattern: {}\nMessage: {}'.format(includestr,
                                                                   ex))
        raise InvalidRegex('Invalid regex: {}'.format(includestr))

    # switch dir so the 'git' command will work correctly.
    try:
        os.chdir(sdir)
    except Exception:
        raise InvalidRepo(sdir)
    # run git ls-files..
    try:
        gitout = subprocess.check_output(['git', 'ls-files'])
    except Exception:
        raise InvalidRepo(sdir)

    if not gitout:
        return []

    try:
        filestr = gitout.decode('utf-8')
    except UnicodeDecodeError as exuni:
        print('\nError decoding git output:\n{}'.format(exuni))
        return []

    # Helper functions for included/excluded files.
    def excluded(f):
        """ Returns True if this file should be excluded from the list. """
        if f:
            # True if no excludepat, False if excludepat doesn't yield a match.
            return (excludepat and excludepat.search(f))
        # Falsey filename, won't be included.
        return False

    def included(f):
        if f:
            # Use includepat if available, otherwise include all.
            return includepat.search(f) if includepat else True
        # Falsey filename, won't be included.
        return False

    # True if this file is included after includestr and excludestr are applied
    # excludes override includes.
    keep_file = lambda f: included(f) and (not excluded(f))

    # Build file list, keep only included files.
    filelist = [f for f in filestr.split('\n') if keep_file(f)]

    if relativepaths:
        # Return list of relative paths.
        return filelist
    else:
        # Return list of full path names.
        return [os.path.join(sdir, f) for f in filelist]


def print_op(oplabel, s=None):
    """ just prints text with some indention.
        print_op('added', 'myfilename.txt')
        # '      added: myfilename.txt'
    """

    oplabel = oplabel.rjust(15)
    if s:
        print(': '.join([oplabel, s]))
    else:
        print(oplabel)


class InvalidRegex(Exception):
    pass


class InvalidRepo(Exception):
    pass

# START OF SCRIPT -----
if __name__ == '__main__':
    mainret = main(docopt(USAGESTR, version=VERSIONSTR))
    sys.exit(mainret)
