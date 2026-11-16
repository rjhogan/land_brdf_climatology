% Close an HDF4 file
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
%
% Note that this script is more memory hungry than some of the earlier
% processing because it holds entire global fields in memory at once


function close_hdf4_file(sdID)
  import matlab.io.hdf4.*
  [ndatasets,nglobal_attr] = sd.fileInfo(sdID);
  for sds_index = 0:ndatasets-1,
    sdsID=sd.select(sdID, sds_index);
    sd.endAccess(sdsID);
  end
  sd.close(sdID);
