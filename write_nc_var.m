% Write a single variable to a NetCDF file
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


function write_nc_var(ncid, varname, data, start, count);

  varid = netcdf.inqVarID(ncid,varname);
  %varattributes = getfield(attributes, variable_names{ii});
  %[no_fill_mode,fill_value] = netcdf.getVarFill(ncid, varid);
  %if ~no_fill_mode
  %  data(find(isnan(data))) = fill_value;
  %end
  if nargin < 5
    disp(['   Filling variable ' varname]);
    netcdf.putVar(ncid,varid,data);
  else
    netcdf.putVar(ncid,varid,start,count,data);
  end

end % function

function [nc_class, straightjacket]  = class2ncclass(variable)

matclass = class(variable);
straightjacket = '';
if strcmp(matclass, 'double') | strcmp(matclass, 'single')
  nc_class = 'NC_FLOAT'; % Only ever output floats...
elseif strcmp(matclass, 'char')
  nc_class = 'NC_CHAR';
elseif strcmp(matclass, 'int8')
  nc_class = 'NC_BYTE';
elseif strcmp(matclass, 'int16')
  nc_class = 'NC_SHORT';
  straightjacket = 'double';
elseif strcmp(matclass, 'int32')
  nc_class = 'NC_INT';
else
  warning(['Unable to save matlab variables of type ' matclass ' in NetCDF']);
  nc_class = '';
end

end % function
