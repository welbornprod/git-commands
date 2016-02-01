#!/usr/bin/env python3
# -*- coding: utf-8 -*-

""" git-authors.py
    ...
    -Christopher Welborn 06-16-2015
"""

import os
import subprocess
import sys
import time

from docopt import docopt

NAME = 'git-authors'
VERSION = '0.0.1'
VERSIONSTR = '{} v. {}'.format(NAME, VERSION)
SCRIPT = os.path.split(os.path.abspath(sys.argv[0]))[1]
SCRIPTDIR = os.path.abspath(sys.path[0])

USAGESTR = """{versionstr}
    Usage:
        {script} [-h | -v]
        {script} [DIR]

    Options:
        DIR           : Repo directory to use.
        -h,--help     : Show this help message.
        -v,--version  : Show {name} version and exit.
""".format(name=NAME, script=SCRIPT, versionstr=VERSIONSTR)


def main(argd):
    """ Main entry point, expects doctopt arg dict as argd. """
    if argd['DIR']:
        try:
            os.chdir(argd['DIR'])
        except FileNotFoundError:
            print('\nDirectory not found: {}'.format(argd['DIR']))
            return 1

    authorcnt = get_authors()
    return 0 if authorcnt else 1


def get_authors():
    """ Run git, process it's output. Print any errors.
        On success, print a formatted version of the repo's authors.
        Return the total number of authors printed.
    """
    # git log --encoding=utf-8 --full-history --reverse
    # --format=format:%at;%an;%ae
    gitcmd = (
        'git',
        'log',
        '--encoding=utf-8',
        '--full-history',
        '--reverse',
        '--format=format:%at;%an;%ae'
    )
    git = subprocess.Popen(
        gitcmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE)

    gitout, giterr = git.communicate()

    # Check for errors.
    if giterr:
        print('\nGit error:\n  {}'.format(giterr.decode('utf-8')))
        return 0
    elif gitout:
        # String mode was fast enough, just use it's lines.
        authorcnt = parse_authors(gitout.splitlines())
        return authorcnt

    print('\nGit error:\n  No output from the git command.')
    return 0


def parse_authors(iterable):
    """ Read author lines from an iterable in the format:
            timestamp;name;email
        Print a better formatted version to stdout.
    """

    seen = set()
    # The format for number, date, name, email
    formatline = '{num:04d} [{date}]: {name} <{mail}>'.format

    for rawline in iterable:
        if not rawline.strip():
            continue
        line = rawline.decode('utf-8')
        try:
            timestamp, name, mail = line.strip().split(';')
        except ValueError as exformat:
            # Line is not formatted correctly.
            raise ValueError(
                'Malformed input: {!r}'.format(line.strip())) from exformat
        if name in seen:
            continue
        seen.add(name)
        date = time.strftime('%Y-%m-%d', parse_time(timestamp))
        try:
            print(formatline(
                num=len(seen),
                date=date,
                name=name,
                mail=mail))
        except BrokenPipeError:
            # Commands like `head` will close the pipe before we are done.
            break
    return len(seen)


def parse_time(s):
    """ Parse a string timestamp into a Time. """
    return time.gmtime(float(s))

if __name__ == '__main__':
    mainret = main(docopt(USAGESTR, version=VERSIONSTR))
    sys.exit(mainret)
