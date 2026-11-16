% Run the various scripts to create a MODIS land-surface albedo climatology
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


% Load settings
settings

% Average daily MODIS albedo files into monthly files for each quality
% group
average_modis_albedo

% Merge the files above considering also adjacent months in order that
% the final climatology averages at least a certain number of days
merge_modis_albedo

% Fill remaining missing pixels by interpolation
fill_modis_albedo

% Convert HDF4 files to NetCDF4/HDF5
convert_data_and_status_to_h5

%calc_white_black_sky_albedo
