#!/usr/bin/env python3
#------------------------------------------------------------------------------#
#  DFTB+: general package for performing fast atomistic simulations            #
#  Copyright (C) 2006 - 2020  DFTB+ developers group                           #
#                                                                              #
#  See the LICENSE file for terms of usage and distribution.                   #
#------------------------------------------------------------------------------#
#
'''Convert DFTB+ gen format to XYZ.'''

import sys
import optparse
from dptools.gen import Gen
from dptools.xyz import Xyz

USAGE = '''usage: %prog [options] INPUT

Converts the given INPUT file in DFTB+ GEN format to XYZ. Per default, if the
filename INPUT is of the form PREFIX.gen the result is stored in PREFIX.xyz,
otherwise in INPUT.xyz. You can additionally store lattice vectors of the GEN
file in a separate file.'''

def main(cmdlineargs=None):
    '''Main driver routine for gen2xyz.

    Args:
        cmdlineargs: List of command line arguments. When None, arguments in
            sys.argv are parsed (Default: None).
    '''
    infile, options = parse_cmdline_args(cmdlineargs)
    gen2xyz(infile, options)

def parse_cmdline_args(cmdlineargs=None):
    '''Parses command line arguments.

    Args:
        cmdlineargs: List of command line arguments. When None, arguments in
            sys.argv are parsed (Default: None).
    '''
    parser = optparse.OptionParser(usage=USAGE)
    parser.add_option("-l", "--lattice-file", action="store", dest="lattfile",
                      help="store lattice vectors in an external file")
    parser.add_option("-o", "--output", action="store", dest="output",
                      help="override the name of the output file (use '-' for "
                      "standard output)")
    parser.add_option("-c", "--comment", action="store", dest="comment",
                      default="", help="comment for the second line of the "
                      "xyz-file")
    (options, args) = parser.parse_args(cmdlineargs)

    if len(args) != 1:
        parser.error("You must specify exactly one argument (input file).")
    infile = args[0]

    return infile, options

def gen2xyz(infile, options):
    '''Converts the given INPUT file in DFTB+ GEN format to XYZ format.

    Args:
        infile: File containing the gen-formatted geometry.
        options: Options (e.g. as returned by the command line parser).
    '''
    gen = Gen.fromfile(infile)
    xyz = Xyz(gen.geometry, options.comment)
    if options.output:
        if options.output == "-":
            outfile = sys.stdout
        else:
            outfile = options.output
    else:
        if infile.endswith(".gen"):
            outfile = infile[:-4] + ".xyz"
        else:
            outfile = infile + ".xyz"
    xyz.tofile(outfile)

    if gen.geometry.periodic and options.lattfile:
        fp = open(options.lattfile, "w")
        for vec in gen.geometry.latvecs:
            fp.write("{0:18.10E} {1:18.10E} {2:18.10E}\n".format(*vec))
        fp.close()
