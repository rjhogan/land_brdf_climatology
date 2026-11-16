% Create NetCDF file but don't write any variables
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

function ncid = create_nc_struct(nc_file, dimensions, attributes, is_hdf);

if nargin < 4
  is_hdf = 0;
end

if ~is_hdf
  disp(['Creating ' nc_file]);
  ncid = netcdf.create(nc_file, netcdf.getConstant('CLOBBER'));
else
  disp(['Writing ' nc_file ' (NetCDF4/HDF5)']);
  %ncid = netcdf.create(nc_file, bitor(netcdf.getConstant('CLOBBER'),netcdf.getConstant('NETCDF4')));
  unix(['rm -f ' nc_file]);
  ncid = netcdf.create(nc_file, netcdf.getConstant('NETCDF4'));
end

% Define dimensions
dimension_names = fieldnames(dimensions);
for ii = 1:length(dimension_names)
  disp(['   Adding dimension ' dimension_names{ii}]);
  netcdf.defDim(ncid,dimension_names{ii},getfield(dimensions, dimension_names{ii}));
end

% Set global attributes
if isfield(attributes,'global')
  attribute_names = fieldnames(attributes.global);
  GLOBAL = netcdf.getConstant('GLOBAL');
  for ii = 1:length(attribute_names)
    disp(['   Adding global attribute ' attribute_names{ii}]);
    value = getfield(attributes.global, attribute_names{ii});
    netcdf.putAtt(ncid, GLOBAL, attribute_names{ii}, convert_type(value));
  end
else
  warning('No global attributes found');
end

				% Set variable information
variable_names = fieldnames(attributes);
for ii = 1:length(variable_names)
  if strcmp(variable_names{ii},'global')
    continue;
  end
  disp(['   Adding variable ' variable_names{ii}]);
  value = getfield(attributes, variable_names{ii});
  varattributes = getfield(attributes, variable_names{ii});
  vardimid = [];
  if isfield(varattributes,'dimensions')
    if ~isempty(varattributes.dimensions)
      vardimensions = getfield(varattributes, 'dimensions');
      for jj = 1:length(vardimensions)
	vardimid(jj) = netcdf.inqDimID(ncid,vardimensions{jj});
      end
    end
  end
  % Set the class of the variable
  nc_class = varattributes.NCClass_;
  %varattributes = rmfield(varattributes,'NCClass_');

  varid = netcdf.defVar(ncid,variable_names{ii},nc_class,vardimid);

  % Set attributes
  attribute_names = fieldnames(varattributes);
  for jj = 1:length(attribute_names)
    if strcmp(attribute_names{jj}, 'dimensions') | strcmp(attribute_names{jj},'NCClass_')
      continue;
    elseif strcmp(attribute_names{jj}, 'missing_value')
      %netcdf.defVarFill(ncid,varid,false,varattributes.missing_value);
      %disp(['      setting _FillValue = ' num2str(varattributes.missing_value)]);  
    elseif strcmp(attribute_names{jj}, 'FillValue_')
      %netcdf.defVarFill(ncid,varid,false,varattributes.FillValue_);
      %disp(['      setting _FillValue = ' num2str(varattributes.FillValue_)]);
      value = getfield(varattributes, attribute_names{jj});
      disp(['      adding _FillValue = ' num2str(value)]);
      if is_hdf
	netcdf.defVarFill(ncid, varid, false, convert_type(value));
      else
	netcdf.putAtt(ncid, varid, '_FillValue', convert_type(value));
      end
      continue;
    elseif strcmp(attribute_names{jj}, 'ChunkSizes_')
      value = getfield(varattributes, attribute_names{jj});
      netcdf.defVarChunking(ncid, varid,'CHUNKED',value);
      continue;
    elseif strcmp(attribute_names{jj}, 'DeflateLevel_')
      value = getfield(varattributes, attribute_names{jj});
      netcdf.defVarDeflate(ncid, varid, true, true, value);
      continue;
    end
    disp(['      adding attribute ' variable_names{ii} '.' attribute_names{jj}]);
    value = getfield(varattributes, attribute_names{jj});
    netcdf.putAtt(ncid, varid, attribute_names{jj}, convert_type(value));
  end
end

netcdf.endDef(ncid);

% Now ready to write variables

end % function


function output = convert_type(variable)

matclass = class(variable);
if strcmp(matclass, 'double')
  output = single(variable); % Only ever output floats...
elseif strcmp(matclass, 'char') | strcmp(matclass, 'int8') ...
       | strcmp(matclass, 'int16') | strcmp(matclass, 'int32') | strcmp(matclass, 'single')
  output = variable;
else
  error(['Unable to save matlab variables of type ' matclass ' in NetCDF']);
end

end % function
