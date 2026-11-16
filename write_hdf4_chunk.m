% Write a chunk of an HDF4 file with a single variable
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


function write_hdf4_chunk(sdID, origin, data)
  import matlab.io.hdf4.*
  sdsID=sd.select(sdID, 0);
  sd.writeChunk(sdsID, origin, data);
