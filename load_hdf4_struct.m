% Load entire variables from an HDF4 file into memory
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

function [data,attribute] = load_hdf4_struct(filename, varnames, is_single, start, count);

if ~exist('varnames');
  varnames = {};
end

if nargin < 3
  is_single = 0;
end

if nargin >= 5
  is_verbose = 0;
else
  is_verbose = 1;
end

do_scale = 1;

import matlab.io.hdf4.sd.*

access_mode='read';

if is_verbose
  disp(['Reading ' filename]);
end

SD_id = matlab.io.hdf4.sd.start(filename,access_mode);
if (SD_id == -1)
  error(['Error loading ' filename ' as HDF'])
end

data = [];

[ndatasets,nglobal_attr] = matlab.io.hdf4.sd.fileInfo(SD_id);

for ii = 0:nglobal_attr-1
  [name,data_type,count] = matlab.io.hdf4.sd.attrInfo(SD_id, ii);
  [attr] = matlab.io.hdf4.sd.readAttr(SD_id, ii);
  name = strrep(name,' ','_');
  name = strrep(name,'.','_');
  if name(1) ~= '_';
    eval(['attribute.global.' name ' = attr ;']);
  end
end


for sds_index = 0:ndatasets-1,
  sds_id=matlab.io.hdf4.sd.select(SD_id, sds_index);
  [name,dimsizes,data_type,nattrs] = matlab.io.hdf4.sd.getInfo(sds_id);
  rank=length(dimsizes);
  var_name=strrep(name,' ','_');
  var_name=strrep(var_name,'.','_');
  is_required = 1;
  if ~isempty(varnames)
    is_required = 0;
    for ii = 1:length(varnames)
      if strcmp(varnames{ii}, var_name)
	is_required = 1;
	break
      end
    end
  elseif rank > 2
    is_required = 0;
  end
  
  if is_required
    if is_verbose
      fprintf(1,'%10s:  rank %02d, %10s\n', name,rank,data_type);
    end
%eval(['data.' var_name ' = double(matlab.io.hdf4.sd.readData(sds_id,zeros(rank,1),ones(rank,1),dimsizes));']);
    if nargin >= 5
      if is_single
	data.(var_name) = single(matlab.io.hdf4.sd.readData(sds_id,start,count));
      else
	data.(var_name) = double(matlab.io.hdf4.sd.readData(sds_id,start,count));
      end
    %data.(var_name) = matlab.io.hdf4.sd.readData(sds_id);
    else
      if is_single
	data.(var_name) = single(matlab.io.hdf4.sd.readData(sds_id));
      else
	data.(var_name) = double(matlab.io.hdf4.sd.readData(sds_id));
      end      
    end
    
    [fill] = matlab.io.hdf4.sd.getFillValue(sds_id);
    if is_single
      fill = single(fill);
    else
      fill = double(fill);
    end
    data.(var_name)(find(data.(var_name)==fill)) = NaN;
    
    add_offset = 0;
    scale_factor = 1;
    for ii = 0:nattrs-1
      [name,data_type,count] = matlab.io.hdf4.sd.attrInfo(sds_id, ii);
      [attr] = matlab.io.hdf4.sd.readAttr(sds_id, ii);
      if do_scale
	if strcmp(name, 'add_offset')
	  if is_single
	    add_offset = single(attr);
	  else
	    add_offset = double(attr);
	  end
	  continue;
	elseif strcmp(name, 'scale_factor')
	  if is_single
	    scale_factor = single(attr);
	  else
	    scale_factor = double(attr);
	  end
	  continue;
	end
      end
      if name(1) ~= '_';
	eval(['attribute.' var_name '.' name ' = attr ;']);
      end
    end
    if scale_factor ~= 1.0 | add_offset ~= 0.0
      if is_single
	eval(['data.' var_name ' = single(data.' var_name ') .* scale_factor+add_offset;']);
      else
	eval(['data.' var_name ' = double(data.' var_name ') .* scale_factor+add_offset;']);
      end
    else
      eval(['data.' var_name ' = data.' var_name ' .* scale_factor+add_offset;']);
    end
    if is_verbose
      disp(['   processed with _FillValue=' num2str(fill) ', add_offset=' num2str(add_offset) ', scale_factor=' num2str(scale_factor)]);
    end
  end
end

matlab.io.hdf4.sd.close(SD_id);
