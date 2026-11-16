% This script fills missing pixels by interpolation
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


% Load the settings
settings

% Load land-water mask
if ~exist('lsm','var')
  lsm=loadnc('/perm/parr/modis_albedo_data/MODIS_surface_land_water_elevation.h5',{'land_water_class'});
end

% Input and output directory
indir  = [intermediate_base_dir '/merged'];
outdir = [intermediate_base_dir '/filled'];
if ~exist(outdir,'filled')
  mkdir(intermediate_base_dir,'filled');
end

% Loop over bands
for iband=1:length(bands)
  band=bands(iband);

  % Loop over albedo components
  for icomp=1:length(components)
    component=components{icomp};

    % Loop over months
    for imon=1:length(months)
      month=months(imon);

      % Create output data file
      if do_vis_nir
	basename=[outdir '/MCD43GF_' component '_' band_names{band} '_mon' ...
			 num2str(month,'%02d') '_' num2str(years(1)) '-' num2str(years(end))];
      else
	basename=[outdir '/MCD43GF_' component '_Band' num2str(band) '_mon' ...
			 num2str(month,'%02d') '_' num2str(years(1)) '-' num2str(years(end))];
      end
      outid = create_hdf4_file([basename '.hdf']);

      % Create output status file but only one per set of three albedo
      % components
      if icomp==1
	if do_vis_nir
	  sbasename=[outdir '/MCD43GF_' band_names{band} '_mon' ...
			    num2str(month,'%02d') '_' num2str(years(1)) '-' num2str(years(end))];
	else
	  sbasename=[outdir '/MCD43GF_Band' num2str(band) '_mon' ...
			    num2str(month,'%02d') '_' num2str(years(1)) '-' num2str(years(end))];
	end
	statusid = create_hdf4_file([sbasename '_status.hdf']);
      end

      % Base string of input files
      if do_vis_nir
	basename=[indir '/MCD43GF_' component '_' band_names{band} '_mon' ...
			num2str(month,'%02d') '_' num2str(years(1)) '-' num2str(years(end))];
	sbasename=[indir '/MCD43GF_' band_names{band} '_mon' ...
			 num2str(month,'%02d') '_' num2str(years(1)) '-' num2str(years(end))];
      else
	basename=[indir '/MCD43GF_' component '_Band' num2str(band) '_mon' ...
			num2str(month,'%02d') '_' num2str(years(1)) '-' num2str(years(end))];
	sbasename=[indir '/MCD43GF_Band' num2str(band) '_mon' ...
			 num2str(month,'%02d') '_' num2str(years(1)) '-' num2str(years(end))];
      end

      % Loop over longitude and latitude chunks
      for ilon = 1:nlon
	for ilat = 1:nlat

	  % 0-based chunk location
	  location=[ilon-1 ilat-1];

	  % Load a chunk of merged data
	  data  =double(load_hdf4_chunk([basename '.hdf'],location));
	  status=load_hdf4_chunk([sbasename '_status.hdf'],location);

	  % Create a mask locating the missing data
	  missing=(status==-1);
	  
	  % Speckle fill
	  % Assuming longitudinal periodicity but not latitudinal for this chunk
	  index=find(missing ...
		     & ~missing([end 1:end-1],:) & ~missing([2:end 1],:) ...
		     & ~missing(:,[1 1:end-1])   & ~missing(:,[2:end end]));
	  interpolated_data = 0.25.*(data([end 1:end-1],:) + data([2:end 1],:) ...
				     & +data(:,[1 1:end-1]) +data(:,[2:end end]));
	  data(index) = interpolated_data(index);
	  % Add a new flag type of -2 to indicate that the missing
	  % data were filled by neighbour averaging
	  status(index) = -2;
	  missing(index)= 0;

	  % Missing points with good points in E, W directions
	  index = find(missing & ~missing([end 1:end-1],:) & ~missing([2:end 1],:));
	  interpolated_data = 0.5.*(data([end 1:end-1],:) + data([2:end 1],:));
	  data(index) = interpolated_data(index);
	  status(index) = -2;
	  missing(index)= 0;
	  
          % Missing points with good points in N, S directions
	  nlon=size(data,1);
	  index = find(missing(:,2:end-1) & ~missing(:,1:end-2) & ~missing(:,3:end));
	  if ~isempty(index);
	    interpolated_data = 0.5.*(data(:,1:end-2) + data(:,3:end));
	    data(index+nlon) = interpolated_data(index);
	    status(index+nlon) = -2;
	    missing(index+nlon) = 0;
	  end

	  % Neighbour fill but only of "land" and "shoreline" classes in separate dataset
	  lsm_chunk = lsm.land_water_class(:,[1:chunksize(2)]+(ilat-1).*chunksize(2));

	  % Locate the land and shoreline classes
	  lsm_is_land = (lsm_chunk>=1 & lsm_chunk<=2);

	  % Do E-W fill first because in the polar regions these will be much closer
	  
	  % Neighbour fill from west
	  index = find(missing & lsm_is_land & ~missing([1 1:end-1],:));
	  data(index) = data(index-1);
	  status(index) = -3;
	  missing(index) = 0;
	  % Neighbour fill from east
	  index = find(missing & lsm_is_land & ~missing([2:end end],:));
	  data(index) = data(index+1);
	  status(index) = -3;
	  missing(index) = 0;
	  
	  % Neighbour fill from north
	  index = find(missing(:,2:end) & lsm_is_land(:,2:end) & ~missing(:,1:end-1));
	  data(index+nlon) = data(index);
	  status(index+nlon) = -4;
	  missing(index+nlon) = 0;
	  % Neighbour fill from south
	  index = find(missing(:,1:end-1) & lsm_is_land(:,1:end-1) & ~missing(:,2:end));
	  data(index) = data(index+nlon);
	  status(index) = -4;
	  missing(index) = 0;
	  
	  lsm_is_true_land = (lsm_chunk==1);
	  % Longitudinal fill but only of "land" classes
	  for iilat = 1:chunksize(2)
	    % Find true land with no albedo
	    ibad = find(missing(:,iilat) & lsm_is_true_land(:,iilat));
	    if ~isempty(ibad)
	      % Find potential points to interpolate from including shorelines
	      igood = find(~missing(:,iilat) & lsm_is_land(:,iilat));
	      if ~isempty(igood)
		data(ibad,iilat) = interp1([0;igood;chunksize(1)+1],...
					   data(igood([1 1:end end]),iilat),ibad);
		status(ibad,iilat) = -5;
		missing(ibad,iilat) = 0;
	      end
	    end
	  end

	  % Write chunk of data and revised status with negative values
	  write_hdf4_chunk(outid, location, int16(data));
	  if icomp == 1
	    write_hdf4_chunk(statusid, location, status);
	  end
	end
      end

      % Close the output files
      close_hdf4_file(outid);
      if icomp == 1
	close_hdf4_file(statusid);
      end
    end
  end
end
