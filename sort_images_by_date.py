#!/usr/bin/env python

# Sort images into folders based on their date

import sys
import getopt
import os
import functools
import argparse

# Global Variables and defaults
VERBOSITY = 0


def usage(prog_name):
    print(f"usage: {prog_name} [options] source-dir target-dir")
    print()
    print("Sort images from source-dir into subfolder structure in target-dir based on date.")
    print()
    print("OPTIONS:")
    print(" -a | --adate              Parse date from access date.")
    print(" -c | --cdate              Parse date from creation date.")
    print(" -e | --exif               Parse date from exif.")
    print(" -f | --filename           Parse date from filename.")
    print(" -m | --mdate              Parse date from modification date.")
    print(" -p | --pool-unmatched     Pool files with no matching date in subfolder 'unmatched'.")
    print(" -s | --skip-unmatched     Ignore files with no matching date.")
    print(" -v                        Increase verbosity (up to two times).")


def vprint(min_verbosity, *args, **kwargs):
    if VERBOSITY >= min_verbosity:
        print(*args, **kwargs)


def main(argv):
    target_dir = os.path.dirname(os.path.abspath(argv[0]))
    source_dir = []

    # Parse Options
    pass
    # USE ARGPARSE HERE, SEE CHUMMER AND DOKU

    vprint(2, f"Source Dirs: {source_dir!r}")
    vprint(2, f"Target Dir: {target_dir!r}")


if __name__ == "__main__":
    main(sys.argv)
    sys.exit()
