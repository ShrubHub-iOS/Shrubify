#!/usr/bin/env python3
"""Map Debian beta package versions to valid GitHub tag components."""
import re
import sys


def github_version(version):
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:~beta[1-9]\d*)?', version):
        raise ValueError('Expected X.Y.Z or X.Y.Z~betaN package version')
    return version.replace('~', '-')


if __name__ == '__main__':
    print(github_version(sys.argv[1]))
