% Get information about the chunking of an HDF4 file
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


function [info,dimsizes]=get_chunk_info(filename)
  import matlab.io.hdf4.sd.*

access_mode='read';

disp(['Reading ' filename]);

SD_id = matlab.io.hdf4.sd.start(filename,access_mode);
if (SD_id == -1)
  error(['Error loading ' filename ' as HDF'])
end
[ndatasets,nglobal_attr] = matlab.io.hdf4.sd.fileInfo(SD_id);

for sds_index = 0:ndatasets-1,
  sds_id=matlab.io.hdf4.sd.select(SD_id, sds_index);
  [name,dimsizes,data_type,nattrs] = matlab.io.hdf4.sd.getInfo(sds_id);
  rank=length(dimsizes);
  var_name=strrep(name,' ','_');
  var_name=strrep(var_name,'.','_');
  fprintf(1,'%10s:  rank %02d, %10s\n', name,rank,data_type);
  if rank == 2
    info = matlab.io.hdf4.sd.getChunkInfo(sds_id);
    break;
  end
end
matlab.io.hdf4.sd.close(SD_id);
