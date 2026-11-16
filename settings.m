% Settings for creating a MODIS land-surface albedo climatology
%
% Copyright (C) 2023- ECMWF
%
% This software is licensed under the terms of the Apache Licence Version 2.0
% which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
%
% In applying this licence, ECMWF does not waive the privileges and immunities
% granted to it by virtue of its status as an intergovernmental organisation
% nor does it submit to any jurisdiction.
%
% Author:  Robin Hogan
% Email:   robin.hogan@ecmwf.int


% String added to directory names to indicate the version
verdir = 'v2.2_TEST_RELEASE';

% Base directory containing input data: the MODIS gap-filled files
% should be in <input_base_dir>/<YEAR> subdirectories
input_base_dir = '../modis_albedo_data';

% Base directory for intermediate processing in HDF4 format:
% subdirectories will be
% <intermediate_base_dir>/[averaged|merged|filled]
intermediate_base_dir = [input_base_dir '/intermediate_' verdir];

% Base directory for output data in NetCDF4/HDF5 format:
% subdirectories will be <output_base_dir>/[brdf|quality]
output_base_dir = [input_base_dir '/' verdir];

% Do we process the 2-band (visible + near-infrared) or 7-band data?
do_vis_nir = 0;

% Which bands, months and years will be processed?
months=[1:12];
years=[2017:2021];

% Names of the albedo components
components={'iso','vol','geo'};

% What are the groups of quality status ranges that should be
% averaged? Here we average in three groups, the first containing the
% highest quality data indicated by 0 or 1, the second with 2 or 3 and
% the third (worst quality) with 4, 5 or 6.
qualities={[0 1],[2 3],[4 6]};

% Minimum number of required days per month, per year in the
% climatology. If this is not achieved with the highest quality data
% then the next highest quality will be incorporated until the minimum
% number has been used.
min_days_per_month=10;

% Get list of band names to use to create name of input files. To
% process a limited range of bands, edit "bands" not "band_names"
if do_vis_nir
  bands = [1:2];
  band_names = {'vis','nir'};
else
  bands=[1:7];
  band_names = {'Band1','Band2','Band3','Band4','Band5','Band6','Band7'};
end

% Get year range as a string
year_range=[num2str(years(1)) '-' num2str(years(end))];

% Get the dimension sizes from a single test file
testfile=[input_base_dir '/2021/MCD43GF_vol_Band6_365_2021_V061.hdf'];
[chunksize,dimsize]=get_chunk_info(testfile);
nlon=dimsize(1)./chunksize(1);
nlat=dimsize(2)./chunksize(2);

% And the actual longitude and latitude arrays
latlon=load_hdf4_struct(testfile,{'Longitude','Latitude'});

