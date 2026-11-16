% Convert intermediate HDF4 files to final NetCDF4/HDF5 files
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


% Load settings
settings

% Do we convert the quality status to NetCDF4/HDF5 or only the albedo
% components?
do_convert_quality = 1;

% Input and output directories
indir  = [intermediate_base_dir '/filled_' verdir];
outdir_brdf    = [output_base_dir '/brdf'];
outdir_quality = [output_base_dir '/quality'];
if ~exist(outdir_quality,'dir')
  mkdir(output_base_dir,'brdf');
end
if ~exist(outdir_quality,'dir')
  mkdir(output_base_dir,'quality');
end

% Albedo component names
comps = {'iso','vol','geo'};
compstr = {'isotropic','volumetric','geometric'};
Compstr = {'Isotropic','Volumetric','Geometric'};

monthstr = {'January','February','March','April','May','June','July','August','September','October','November','December'};

% NetCDF4/HDF5 data are first described by the dims and attr structures
clear dims attr

% Set dimensions
dims.latitude  = 21600;
dims.longitude = 43200;

% Chunk sizes for NetCDF4/HDF5 file
chunksize = [1200,1200]; % 10x10 degree chunks
scale_factor = 0.0001;

% Block structure of input MODIS data as well as the intermediate HDF4
% files that replicate it
blocksize = [dims.longitude chunksize(2)];
nblock    = dims.latitude./chunksize(2);

% Define band names and wavelength boundaries
if do_vis_nir
  band_names = {'vis','nir'};
  band_long_names = {'visible','near-infrared'};
  if ~exist('bands','var')
    bands = 1:2;
  end
  wav1=[200 700];
  wav2=[700 4000];
else
  if ~exist('bands','var')
    bands = [1:7];
  end
  wav1=[620 841 459 545 1230 1628 2105];
  wav2=[670 876 479 565 1250 1652 2155];
  wavc=(wav1+wav2)./2;
end

% Loop over bands
for iband = 1:length(bands)
  band=bands(iband);

  % Loop over months
  for imon = 1:length(months)
    month=months(imon);

    % The attr and attr_quality structures describe the data held in
    % the albedo-climatology and quality-status files, respectively
    clear attr attr_quality

    % Year range bounded by year1 and year2
    attr.year1.long_name = 'Start year of average';
    attr.year1.NCClass_ = 'NC_SHORT';
    
    attr.year2.long_name = 'End year of average';
    attr.year2.NCClass_ = 'NC_SHORT';

    % Month as an integer
    attr.month.long_name = 'Month';
    attr.month.comment = 'January=1, February=2 etc.';
    attr.month.NCClass_ = 'NC_SHORT';

    % Bands and wavelength bounds
    if ~do_vis_nir
      attr.band.long_name = 'MODIS band';
      attr.band.NCClass_ = 'NC_SHORT';
    end
    
    attr.wavelength1.long_name = 'Lower wavelength bound';
    attr.wavelength1.units = 'nm';	
    attr.wavelength1.NCClass_ = 'NC_FLOAT';
    
    attr.wavelength2.long_name = 'Upper wavelength bound';
    attr.wavelength2.units = 'nm';
    attr.wavelength2.NCClass_ = 'NC_FLOAT';

    if ~do_vis_nir
      attr.wavelength.long_name = 'Central wavelength';
      attr.wavelength.units = 'nm';
      attr.wavelength.NCClass_ = 'NC_FLOAT';
    end

    % Latitude and longitude of each point
    attr.latitude.long_name = 'Latitude';
    attr.latitude.units = 'degrees_north';
    attr.latitude.dimensions = {'latitude'};
    attr.latitude.NCClass_ = 'NC_FLOAT';
    attr.latitude.standard_name = 'latitude';
	
    attr.longitude.long_name = 'Longitude';
    attr.longitude.units = 'degrees_east';
    attr.longitude.dimensions = {'longitude'};
    attr.longitude.NCClass_ = 'NC_FLOAT';
    attr.longitude.standard_name = 'longitude';

    % Variables so far are common to the albedo-component and
    % quality-status files
    if do_convert_quality
      attr_quality = attr;
    end

    % Define albedo components in output file
    for icomp = 1:length(comps)
      varname = [compstr{icomp}];
      attr.(varname).dimensions = {'longitude','latitude'};
      attr.(varname).long_name = [Compstr{icomp} ' albedo parameter'];
      attr.(varname).scale_factor = scale_factor;
      attr.(varname).add_offset = 0.0;
      attr.(varname).FillValue_ = int16(-1);
      attr.(varname).DeflateLevel_ = 4;
      attr.(varname).ChunkSizes_ = chunksize;
      attr.(varname).NCClass_ = 'NC_SHORT';
    end

    % Set global attributes
    if do_vis_nir
      attr.global.title = [monthstr{month} ' land-surface albedo/BRDF parameters from MODIS ' band_long_names{band} ' band averaged over the years ' year_range];
    else
      attr.global.title = [monthstr{month} ' land-surface albedo/BRDF parameters from MODIS band ' num2str(band) ' averaged over the years ' year_range];
    end
    [status,thedate]=unix('date');
    thedate=thedate(1:end-1);
    attr.global.history = [thedate ': Averaged from daily MODIS HDF files'];
    attr.global.modis_product_version = modis_ver;
    attr.global.software_version = software_version;
    if do_vis_nir
      filename = [outdir_brdf '/MCD43GF_brdf_' band_names{band} '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
    else
      filename = [outdir_brdf '/MCD43GF_brdf_Band' num2str(band) '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
    end
    attr.global.creator_name = 'Robin Hogan';
    attr.global.creator_email = 'r.j.hogan@ecmwf.int';
    attr.global.institution = 'European Centre for Medium-Range Weather Forecasts';
    attr.global.source_url='https://e4ftl01.cr.usgs.gov/MOTA/MCD43GF.061';
    attr.global.references='Schaaf, C. B., F. Gao, A. H. Strahler, W. Lucht, X. Li, T. Tsang, N. C. Strugnell, X. Zhang, Y. Jin, J.-P. Muller, P. Lewis, M. Barnsley, P. Hobson, M. Disney, G. Roberts, M. Dunderdale, C. Doll, R. P. d''Entremont, B. Hu, S. Liang, J. L. Privette and D. Roy, 2002: First operational BRDF, albedo nadir reflectance products from MODIS. Rem. Sens. Env., 83, 135-148, https://doi.org/10.1016/S0034-4257(02)00091-3.';
    attr.global.time_coverage_start=[num2str(years(1)) '-01-01T00:00'];
    attr.global.time_coverage_end=[num2str(years(end)) '-12-31T23:59'];
    if do_vis_nir
      commentstr = ['in the ' band_long_names{band}];
    else
      commentstr = ['at ' num2str(wavc(band)) ' nm'];
    end
    attr.global.comment=wrap_text(['This file contains maps of three parameters that can be used to reconstruct the climatological albedo and bidirectional reflectance distribution function (BRDF) of the land surface ' commentstr ' in ' monthstr{month} ' using the model of Schaaf et al. (2002). It was computed by averaging the daily MODIS gap-filled snow-cleared MCD43GF product (version 6.1) for this month in the years ' year_range '. Additional gap filling using values from other months has been performed to ensure that land areas always have finite values. Since the parameters were sometimes retrieved from a limited set of solar zenith angles, there is no guarantee that the albedos calculated using the Schaaf et al. (2002) model will always return an albedo less than 1, so a cap of 1 should be applied. Missing values over the sea are indicated in the dataset by -1. Users of this product will need to add the albedo of water bodies, sea ice and land snow from another source.'],100);

    % Create the data file; the "1" means use NetCDF4/HDF5 format
    % rather than classic NetCDF3 format
    ncid=create_nc_struct(filename, dims, attr, 1);

    % Define quality_status variable 
    if do_convert_quality
      varname_quality = 'quality_status';
      attr_quality.(varname_quality).dimensions = {'longitude','latitude'};
      attr_quality.(varname_quality).long_name = 'Albedo retrieval quality status';
      attr_quality.(varname_quality).DeflateLevel_ = 4;
      attr_quality.(varname_quality).ChunkSizes_ = chunksize;
      attr_quality.(varname_quality).NCClass_ = 'NC_BYTE';
      attr_quality.(varname_quality).valid_range=int8([-1 26]);
      attr_quality.(varname_quality).definition=...
      ['-1. No retrieval (open water)' 10 ...
     ' 0. Best quality (QA=0 or 1)' 10 ...
     ' 1. Lower quality (QA=2 or 3)' 10 ...
     ' 2. Best quality from adjacent month (QA=0 or 1)' 10 ...
     ' 3. Lower quality from adjacent month (QA=2 or 3)' 10 ...
     ' 4. Best quality from two months away (QA=0 or 1)' 10 ...
     ' 5. Lower quality from two months away (QA=2 or 3)' 10 ...
     ' 6. Poorest quality (QA=4-6)' 10 ...
     ' 7. Poorest quality from adjacent month (QA=4-6)' 10 ...
     ' 8. Poorest quality from two months away (QA=4-6)' 10 ...
     ' 9. Best quality from three months away (QA=0 or 1)' 10 ...
     '10. Lower quality from three months away (QA=2 or 3)' 10 ...
     '11. Poorest quality from three months away (QA=4-6)' 10 ...
     '12. Best quality from four months away (QA=0 or 1)' 10 ...
     '13. Lower quality from four months away (QA=2 or 3)' 10 ...
     '14. Poorest quality from four months away (QA=4-6)' 10 ...
     '15. Best quality from five months away (QA=0 or 1)' 10 ...
     '16. Lower quality from five months away (QA=2 or 3)' 10 ...
     '17. Poorest quality from five months away (QA=4-6)' 10 ...
     '18. Best quality from six months away (QA=0 or 1)' 10 ...
     '19. Lower quality from six months away (QA=2 or 3)' 10 ...
     '20. Poorest quality from six months away (QA=4-6)' 10 ...
     '21. Speckle fill (average of two or four adjacent points)' 10 ...
     '22. Neighbour fill (take adjacent point)' 10 ...
     '23. Longitudinal interpolation' 10 ...
     '24. Adjustment to prevent black-sky albedo exceeding 1 for solar zenith angle of 75 degrees' 10 ...
     '25. Adjustment to prevent white-sky albedo exceeding 1' 10 ...
     '26. Capping albedo at 1 for all solar zenith angles'];
      attr_quality.(varname_quality).comment=wrap_text('This variable contains the quality status for averaged MODIS land-surface albedo parameters. A value of -1 indicates that no retrieval was be performed due to open water being present. The daily MCD43GF dataset contains a QA flag with the following values: 0=best quality, full inversion (WoDs, RMSE majority good); 1=good quality, full inversion; 2=Magnitude inversion (numobs >= 7); 3=Magnitude inversion (numobs >= 2 & < 7); 4=Temporal fit; 5=Spatial fit; 6=Spatial smoothing; and 7=SZN extension. The data for each month were first averaged in three groups: points with QA=0 or 1, points with QA=2 or 3, and points with QA=4 to 6 (points with QA=7 are not used. The averages were then merged, aiming for at least 10 days of data per month averaged. So for a climatology created from 5 years of data, we wished the average at each point to come from least 50 days of data. For each point, we searched through the pre-averaged data from highest to lowest quality and also searching adjacent months. The order of the search is given by numbers 0 to 20 listed in the "definition" attribute. As soon as at least the target number of days was been found, we calculated the final average at each point. This quality status variable contains the weighted average of the numbers from 0 to 20 of the pre-averaged datasets contributing to the final average. After the merge had been performed, some points deemed to be land or shoreline by an auxiliary dataset had points missing. First a speckle fill was performed (assigned status 21), then a nearest neighbour value was sought (assigned a status 22) and then a longitudinal interpolation is performed (assigned a status of 23) although almost all of these final points are in Antarctica or Greenland. Finally, an adjustment is made to the three parameters where necessary to prevent black-sky albedo at low sun, white-sky albedo, or both, from exceeding 1 (status 24-26).',100);

      % Global attributes specific to quality-status file
      if do_vis_nir
	attr_quality.global.title = ['Quality status of ' monthstr{month} ' land-surface albedo/BRDF parameters from MODIS ' band_long_names{band} ' band averaged over the years ' year_range];
      else
	attr_quality.global.title = ['Quality status of ' monthstr{month} ' land-surface albedo/BRDF parameters from MODIS band ' num2str(band) ' averaged over the years ' year_range];
      end
      [status,thedate]=unix('date');
      thedate=thedate(1:end-1);
      attr_quality.global.history = [thedate ': Averaged from daily MODIS HDF files'];
      attr_quality.global.modis_product_version = modis_ver;
      if do_vis_nir
	filename_quality = [outdir_quality '/MCD43GF_quality_' band_names{band} '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
      else
	filename_quality = [outdir_quality '/MCD43GF_quality_Band' num2str(band) '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
      end
      attr_quality.global.creator_name = 'Robin Hogan';
      attr_quality.global.creator_email = 'r.j.hogan@ecmwf.int';
      attr_quality.global.institution = 'European Centre for Medium-Range Weather Forecasts';
      attr_quality.global.source_url='https://e4ftl01.cr.usgs.gov/MOTA/MCD43GF.061';
      attr_quality.global.references='Schaaf, C. B., F. Gao, A. H. Strahler, W. Lucht, X. Li, T. Tsang, N. C. Strugnell, X. Zhang, Y. Jin, J.-P. Muller, P. Lewis, M. Barnsley, P. Hobson, M. Disney, G. Roberts, M. Dunderdale, C. Doll, R. P. d''Entremont, B. Hu, S. Liang, J. L. Privette and D. Roy, 2002: First operational BRDF, albedo nadir reflectance products from MODIS. Rem. Sens. Env., 83, 135-148, https://doi.org/10.1016/S0034-4257(02)00091-3.';
      attr_quality.global.time_coverage_start=[num2str(years(1)) '-01-01T00:00'];
      attr_quality.global.time_coverage_end=[num2str(years(end)) '-12-31T23:59'];
      attr_quality.global.comment=wrap_text(['The original daily MODIS gap-filled snow-cleared MCD43GF dataset is described by Schaaf et al. (2002).'],100);
      
      % Create the quality-status data file
      ncid_quality=create_nc_struct(filename_quality, dims,
				    attr_quality, 1);
    end

    % Create an array of NetCDF IDs
    if do_convert_quality
      ncids = [ncid ncid_quality];
    else
      ncids = ncid;
    end

    % Loop over output files and write coordinate variables
    for incid=1:length(ncids)
      nn=ncids(incid);
        
      write_nc_var(nn, 'year1', years(1));
      write_nc_var(nn, 'year2', years(end));
      write_nc_var(nn, 'month', month);
      if ~do_vis_nir
	write_nc_var(nn, 'band', band);
      end
      write_nc_var(nn, 'wavelength1', wav1(band));
      write_nc_var(nn, 'wavelength2', wav2(band));
      if ~do_vis_nir
	write_nc_var(nn, 'wavelength', 0.5*(wav1(band)+wav2(band)));
      end
      write_nc_var(nn, 'latitude', latlon.Latitude);
      write_nc_var(nn, 'longitude', latlon.Longitude);
    end

    % Loop over input blocks
    for iblock = 1:nblock
      disp(['Processing block ' num2str(iblock) ' of ' num2str(nblock)]);
      start=[0 (iblock-1).*blocksize(2)];

      % Load quality status
      if do_vis_nir
	[stat]=load_hdf4_struct([indir '/MCD43GF_' band_names{band} ...
			 '_mon' num2str(month,'%02d') '_' year_range '_status.hdf'], {}, 0, start, blocksize);
      else
	[stat]=load_hdf4_struct([indir '/MCD43GF_Band' num2str(band) ...
			 '_mon' num2str(month,'%02d') '_' year_range '_status.hdf'], {}, 0, start, blocksize);
      end

      % Loop over albedo components
      for icomp = 1:length(comps)
	varname = [compstr{icomp}];

	% Load data
	if do_vis_nir
	  data=load_hdf4_struct([indir '/MCD43GF_' comps{icomp} ...
	     '_' band_names{band} '_mon' num2str(month,'%02d') '_' year_range '.hdf'], {}, 0, start, blocksize);
	else
	  data=load_hdf4_struct([indir '/MCD43GF_' comps{icomp} ...
	     '_Band' num2str(band) '_mon' num2str(month,'%02d') '_' year_range '.hdf'], {}, 0, start, blocksize);
	end
	% Store albedo component, converting from the scaled integer
	albedo.(varname) = data.variable.*0.0001;
	clear data
      end

      % Check albedo is less than 1 for solar zenith angles less than 75 degrees
      disp(['  Bounding albedo components']);
      [new.isotropic, new.volumetric, new.geometric, bound_mask] ...
        = bound_albedo_components(albedo.isotropic,albedo.volumetric,albedo.geometric);

      % Write a chunk of albedo components, ensuring that the "-1"
      % code for missing data (i.e. deep ocean) is retained after
      % scaling to an integer
      index = find(stat.variable==-1);
      for icomp = 1:length(compstr)
	data = new.(compstr{icomp}).*10000;
	data(index) = -1;
	write_nc_var(ncid, compstr{icomp}, data, start, blocksize);
      end

      % Translate negative status values to positive ones above the
      % existing range so that a higher number unambiguously means a
      % worse quality
      if do_convert_quality
	index=find(stat.variable==-2);
	stat.variable(index)=21;
      
	index=find(stat.variable==-3|stat.variable==-4);
	stat.variable(index)=22;
      
	index=find(stat.variable==-3|stat.variable==-5);
	stat.variable(index)=23;
      
	index=find(bound_mask==1);
	stat.variable(index)=24;
      
	index=find(bound_mask==2);
	stat.variable(index)=25;

	index=find(bound_mask==3);
	stat.variable(index)=26;
      
	% Write a chunk of albedo data
	write_nc_var(ncid_quality, varname_quality, stat.variable, start, blocksize);
      end
      
    end

    % Close files
    netcdf.close(ncid);
    if do_convert_quality
      netcdf.close(ncid_quality);
    end
  end
end
