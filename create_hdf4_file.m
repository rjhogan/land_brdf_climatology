% Create an HDF4 file with a single variable of size to contain an
% intermediate MODIS albedo component
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


function [sdID]=create_hdf4_file(filename)
  import matlab.io.hdf4.*
  if exist(filename,'file')
    disp(['Deleting existing ' filename]);
    delete(filename)
  end
  sdID = sd.start(filename,'create');
  sdsID = sd.create(sdID,'variable','int16',[43200 21600]);
  sd.setChunk(sdsID,[43200 100],'deflate',3);
  sd.setFillValue(sdsID,int16(-999));


  
