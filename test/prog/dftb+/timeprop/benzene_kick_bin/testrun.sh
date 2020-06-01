#!/bin/bash

# Run a restarted electron dynamics from a save file

DFTBPLUS_CMD=$*

# Restart test wit electron dynamics
for jobs in initial final
do
    rm -f dftb_in.hsd
    cp $jobs.hsd dftb_in.hsd
    $DFTBPLUS_CMD
done
