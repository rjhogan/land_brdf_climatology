# Create land-surface albedo/BRDF climatology

This document last updated 16 November 2026

Robin Hogan <robin.hogan@ecmwf.int>

## Overview

This package creates a seven-band snow-cleared gap-filled land-surface
bidirectional reflectance distribution function (BRDF) climatology
from the MODIS MCD43GF daily dataset. The BRDF is parameterized by
three albedo coefficients as described by [Schaaf et
al. 2002](https://digitalcommons.unl.edu/cgi/viewcontent.cgi?article=1037&amp&context=nasapub&amp&sei-redir=1&referer=https%253A%252F%252Fscholar.google.co.uk%252Fscholar%253Fq%253Dschaaf%252B2002%252Bmodis%2526hl%253Den%2526as_sdt%253D0%2526as_vis%253D1%2526oi%253Dscholart#search=%22schaaf%202002%20modis%22).
Further information on the method used in this code is available on
the [Land surface BRDF climatology web
site](https://confluence.ecmwf.int/spaces/ECRAD/pages/589478193/Land+surface+BRDF+climatology).

## How to run

You first need to download several years of the MODIS MCD43GF (where
GF means "gap filled") land-surface BRDF dataset, version 6.1, and put
into subdirectories by year. The format is HDF4. The dataset is large:
over 2 TB per year.  The file names are of the form
`MCD43GF_<COMPONENT>_Band<BAND>_<JULIAN>_<YEAR>_V061.hdf` and
`MCD43GF_qa_Band<BAND>_<JULIAN>_<YEAR>_V061.hdf`, where `COMPONENT` is one
of `iso`, `geo`, `vol`, `BAND` is from `1` to `7` and `JULIAN` is the Julian
day.

The package consists of a number of Matlab scripts. First edit the
`settings.m` script to select the years you wish to run, the bands you
wish to process, and the locations of the input, intermediate and
output directories.  The "intermediate" directory stores data in
various stages of processing in HDF4 format. The final output format
is NetCDF4/HDF5.

The `do_all.m` script runs each of the necessary scripts in order. You
can alternatively run these scripts manually from the Matlab command
line Since the processing takes a long time you may wish to run in
parallel with separate Matlab instances running a different band, but
you would need edit `settings.m` each time. Since the underlying
dataset is so large, this will likely take several days.

