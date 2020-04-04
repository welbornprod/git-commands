#!/usr/bin/env python3
# -*- coding: utf-8 -*-

""" git-authorz.py
    Get a list of authors for a git repo.
    -Christopher Welborn 06-16-2015
"""

import os
import requests
import subprocess
import sys
import time

from colr import (
    Colr as C,
    docopt,
)
from easysettings import load_json_settings

NAME = 'git-authorz'
VERSION = '0.0.1'
VERSIONSTR = '{} v. {}'.format(NAME, VERSION)
SCRIPT = os.path.split(os.path.abspath(sys.argv[0]))[1]
SCRIPTDIR = os.path.abspath(sys.path[0])
CONFIGNAME = 'git-authorz.json'
CONFIGFILE = os.path.join(SCRIPTDIR, CONFIGNAME)

config = load_json_settings(
    [CONFIGNAME, CONFIGFILE],
    default={
        'github_user': None,
    }
)

GH_USER = config['github_user'] or '<not set>'
USAGESTR = f"""{VERSIONSTR}
    Usage:
        {SCRIPT} [-h | -v]
        {SCRIPT} [DIR]
        {SCRIPT} -g [-u name] [-r name] [DIR]

    Options:
        DIR                  : Repo directory to use.
        -g,--github          : Get authors from github repo.
        -h,--help            : Show this help message.
        -r name,--repo name  : Name of github repo, if not the same as CWD.
        -u name,--user name  : Owner of github repo, if not set in config.
                               Config setting: {GH_USER}
        -v,--version         : Show {NAME} version and exit.
"""



def main(argd):
    """ Main entry point, expects doctopt arg dict as argd. """
    if argd['--github']:
        exitcode = get_github_authors(
            username=argd['--user'],
            repo=argd['--repo'],
            fallback_dir=argd['DIR'],
        )
        return exitcode

    if argd['DIR']:
        try:
            os.chdir(argd['DIR'])
        except FileNotFoundError:
            print('\nDirectory not found: {}'.format(argd['DIR']))
            return 1

    exitcode = get_authors()
    return exitcode


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


def get_github_authors(username=None, reponame=None, fallback_dir=None):
    if not username:
        username = config.get('github_user', None)
    if username is None:
        raise InvalidArg('No github user name specified in options/config!')

    if not reponame:
        reponame = os.path.split(fallback_dir or os.getcwd())[-1]
    api_url = f'repos/{username}/{reponame}/contributors'
    url = f'https://api.github.com/{api_url}'
    resp = requests.get(url)
    authors = resp.json()
    for authorinfo in authors:
        login = authorinfo['login']
        author_url = authorinfo['url']
        print(f'[{login}]({author_url})')
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


def print_err(*args, **kwargs):
    """ A wrapper for print() that uses stderr by default.
        Colorizes messages, unless a Colr itself is passed in.
    """
    if kwargs.get('file', None) is None:
        kwargs['file'] = sys.stderr

    # Use color if the file is a tty.
    if kwargs['file'].isatty():
        # Keep any Colr args passed, convert strs into Colrs.
        msg = kwargs.get('sep', ' ').join(
            str(a) if isinstance(a, C) else str(C(a, 'red'))
            for a in args
        )
    else:
        # The file is not a tty anyway, no escape codes.
        msg = kwargs.get('sep', ' ').join(
            str(a.stripped() if isinstance(a, C) else a)
            for a in args
        )

    print(msg, **kwargs)


class InvalidArg(ValueError):
    """ Raised when the user has used an invalid argument. """
    def __init__(self, msg=None):
        self.msg = msg or ''

    def __str__(self):
        if self.msg:
            return f'Invalid argument, {self.msg}'
        return 'Invalid argument!'


if __name__ == '__main__':
    try:
        mainret = main(docopt(USAGESTR, version=VERSIONSTR, script=SCRIPT))
    except InvalidArg as ex:
        print_err(ex)
        mainret = 1
    except (EOFError, KeyboardInterrupt):
        print_err('\nUser cancelled.\n')
        mainret = 2
    except BrokenPipeError:
        print_err('\nBroken pipe, input/output was interrupted.\n')
        mainret = 3
    sys.exit(mainret)
