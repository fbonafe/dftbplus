DPTOOLS: Processing and converting data related to the DFTB+ package
********************************************************************

This package contains a few scripts which should make the life of
DFTB+ users easier by providing functions to process and convert
various DFTB+ data formats. It currently contains the following
utilities:

dp_bands
  Creates plotable band structure data from band.out

dp_dos
  Creates plotable density of states or partial density of states data
  by convolving the data produced by DFTB+ with (usually) gaussian
  broadening functions.

gen2cif
  Converts a file in gen format to cif, which contains information
  about the periodic boundary conditions. Among others, Jmol is
  capable of visualising cif files.

gen2xyz
  Converts a file in gen format to xyz in order to visualise it with
  practically all available molecular visualisers.

xyz2gen
  Converts an xyz file to gen file.

straingen
  Applies uniaxial, isotropic or shear strains to geometries,
  with principle axes aligned with the cartesian directions.

repeatgen
  Can be used to build supercell structures for phonon bandstructures

Each script can be invoked with the option ``-h`` to obtain a short
summary about its usage and possible options.


Testing dp_tools
================

In the chosen build directory (as set via cmake), running

ctest -R dptools

will validate the source of dp_tools for your python interpreter and
environment.


For developers
--------------

To perform pylint static checking, in the top DFTB+ directory the
individual scripts can be tested, for example by ::

  env PYTHONPATH=$PWD/tools/dptools/src pylint3 --rcfile \
  utils/srccheck/pylint/pylintrc-3.ini tools/dptools/src/dptools/*


Installation
============

Please note, that this package has been tested for **Python 3.X**
support. It additionally needs Numerical Python (the numpy module).

You can install the script package via the standard 'pip'
mechanism::

  python -m pip install .

with an appropriate level of permissions.
