% Calculate white- and (optionally) black-sky albedo from BRDF
% climatology and store to a NetCDF4/HDF5 file
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

% Select the resolution to process by uncommenting one of the
% following files (the BRDF climatology must have already been created
% at the requested resolution)
res='';average_points=1;
%res='0.025deg';average_points = 3;
%res='0.05deg';average_points = 6;
%res='0.1deg';average_points = 12;
%res='0.2deg';average_points = 24;
%res='0.4deg';average_points = 48;

% Work out input and output directories
if ~isempty(res)
  indir =[output_base_dir '/' res];
  outdir=[output_base_dir '/' res '/wsa'];
  filetag = ['-' res];
else
  indir =[output_base_dir];
  outdir=[output_base_dir '/wsa'];
  filetag = '';
end
if ~exist(outdir,'dir')
  mkdir(indir,'wsa');
end

% Do we store black-sky albedo at selected solar zenith angles?
do_bsa=0;

% For diagnosing problems with individual super reflective pixels it
% can be useful to output a text file containing their location
save_super_reflective = 0;

if do_vis_nir
  band_long_names = {'visible','near-infrared'};
end

components={'isotropic','volumetric','geometric'};
monthstr = {'January','February','March','April','May','June','July','August','September','October','November','December'};

nlat=21600/average_points;
nlon=43200/average_points;

% Define dimensions
dims.latitude = nlat;
dims.longitude = nlon;

% Define chunk size
if average_points > 1
  nchunk=1200*3/average_points;
else
  nchunk=1200;
end
nlatchunk=nlat./nchunk;
nlonchunk=nlon./nchunk;
chunksize=[nchunk,nchunk];
scale_factor = 0.0001;

% Define output data variables
if do_bsa
  outvars = {'wsa','bsa0','bsa75'};
else
  outvars = {'wsa'};
end

% Loop over bands
for iband=1:length(bands)
  band=bands(iband);

  % Loop over months
  for imon=1:length(months)
    month=months(imon);

    % Define file names
    if do_vis_nir
      inbase = ['MCD43GF_brdf' filetag '_' band_names{band} '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
      qfile = [indir '/quality/MCD43GF_quality' filetag '_' band_names{band} '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
      outfile = [outdir '/MCD43GF_wsa' filetag '_' band_names{band} '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
    else
      inbase = ['MCD43GF_brdf' filetag '_Band' num2str(band) '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
      qfile = [indir '/quality/MCD43GF_quality' filetag '_Band' num2str(band) '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
      outfile = [outdir '/MCD43GF_wsa' filetag '_Band' num2str(band) '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
    end
    infile = [indir '/brdf/' inbase];
    infile = [indir '/brdf/' inbase];

    % Create text file for super-reflective pixels, if required
    if save_super_reflective
      if do_vis_nir
	fid=fopen([outdir '/MCD43GF_' band_names{band} '_mon' num2str(month,'%02d') '_' year_range '_bad_albedo_' Ver '.txt'],'w');
      else
	fid=fopen([outdir '/MCD43GF_Band' num2str(band) '_mon' num2str(month,'%02d') '_' year_range '_bad_albedo_' Ver '.txt'],'w');
      end
      fprintf(fid,'%% band, month, ilon, ilat, iso, vol, geo, quality, wsa, bsa0, bsa75\n');
    end

    % Auxiliary variables to store
    if do_vis_nir
      auxvars={'year1','year2','month','wavelength1','wavelength2','latitude','longitude'};
    else
      auxvars={'year1','year2','month','band','wavelength1','wavelength2','wavelength','latitude','longitude'};
    end

    % Load the  input file
    [data,attr,dims]=loadnc(infile,auxvars);

    % Populate attribute structure from which output file will be created
    attr.year1.NCClass_ = 'NC_SHORT';
    attr.year2.NCClass_ = 'NC_SHORT';
    attr.month.NCClass_ = 'NC_SHORT';
    if ~do_vis_nir
      attr.band.NCClass_  = 'NC_SHORT';
      attr.wavelength.NCClass_  = 'NC_FLOAT';
    end
    attr.wavelength1.NCClass_ = 'NC_FLOAT';
    attr.wavelength2.NCClass_ = 'NC_FLOAT';
    attr.latitude.NCClass_    = 'NC_FLOAT';
    attr.longitude.NCClass_   = 'NC_FLOAT';

    attr.wsa.long_name = 'White-sky albedo';
    if do_bsa
      attr.bsa0.long_name = 'Black-sky albedo for overhead sun';
      attr.bsa75.long_name = 'Black-sky albedo for solar zenith angle of 75 degrees';
    end
    for ivar = 1:length(outvars)
      attr.(outvars{ivar}).dimensions = {'longitude','latitude'};
      attr.(outvars{ivar}).scale_factor = scale_factor;
      attr.(outvars{ivar}).add_offset = 0.0;
      attr.(outvars{ivar}).FillValue_ = int16(-1);
      attr.(outvars{ivar}).DeflateLevel_ = 4;
      attr.(outvars{ivar}).ChunkSizes_ = chunksize;
      attr.(outvars{ivar}).NCClass_ = 'NC_SHORT';
    end

    % Copy over global attributes
    attr_global=attr.global;
    attr=rmfield(attr,'global');

    % Set global attributes
    if do_vis_nir
      attr.global.title = [monthstr{month} ' land-surface white-sky albedo for the MODIS ' band_long_names{band} ' band averaged over the years ' year_range];
    else
      attr.global.title = [monthstr{month} ' land-surface white-sky albedo for MODIS band ' num2str(band) ' averaged over the years ' year_range];
    end
    [status,thedate]=unix('date');
    thedate=thedate(1:end-1);
    attr.global.history = [thedate ': Calculated from albedo climatology file'];
    attr.global.source = inbase;
    attr.global.modis_product_version = attr_global.modis_product_version;
    attr.global.software_version = attr_global.software_version;
    if do_vis_nir
      filename = [outdir '/MCD43GF_' band_names{band} '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
    else
      filename = [outdir '/MCD43GF_Band' num2str(band) '_mon' num2str(month,'%02d') '_' year_range '_' Ver '.h5'];
    end
    attr.global.creator_name = 'Robin Hogan';
    attr.global.creator_email = 'r.j.hogan@ecmwf.int';
    attr.global.institution = 'European Centre for Medium-Range Weather Forecasts';
    attr.global.source_url='https://e4ftl01.cr.usgs.gov/MOTA/MCD43GF.061';
    attr.global.references='Schaaf, C. B., F. Gao, A. H. Strahler, W. Lucht, X. Li, T. Tsang, N. C. Strugnell, X. Zhang, Y. Jin, J.-P. Muller, P. Lewis, M. Barnsley, P. Hobson, M. Disney, G. Roberts, M. Dunderdale, C. Doll, R. P. d''Entremont, B. Hu, S. Liang, J. L. Privette and D. Roy, 2002: First operational BRDF, albedo nadir reflectance products from MODIS. Rem. Sens. Env., 83, 135-148, https://doi.org/10.1016/S0034-4257(02)00091-3.';
    attr.global.time_coverage_start=[num2str(years(1)) '-01-01T00:00'];
    attr.global.time_coverage_end=[num2str(years(end)) '-12-31T23:59'];
    if do_vis_nir
      attr.global.comment=wrap_text(['This file contains the climatological snow-cleared land-surface white-sky albedo for the MODIS ' band_long_names{band} ' band in ' monthstr{month} ', computed from a climatology of the three albedo parameters described by Schaaf et al. (2002). Missing values over the sea are indicated in the dataset by -1.'],100);
    else
      attr.global.comment=wrap_text(['This file contains the climatological snow-cleared land-surface white-sky albedo at ' num2str(data.wavelength) ' nm in ' monthstr{month} ', computed from a climatology of the three albedo parameters described by Schaaf et al. (2002). Missing values over the sea are indicated in the dataset by -1.'],100);
    end

    % Create output file
    ncid=create_nc_struct(outfile, dims, attr, 1);

    % Write auxiliary variables
    for ivar = 1:length(auxvars)
      write_nc_var(ncid, auxvars{ivar}, data.(auxvars{ivar}));
    end

    % Loop over data chunks
    for ilatchunk = 1:nlatchunk
      for ilonchunk = 1:nlonchunk
	disp(sprintf('Chunk %d %d', ilonchunk, ilatchunk));
	start = [(ilonchunk-1).*nchunk,(ilatchunk-1).*nchunk];

	% Load a chunk containing all three albedo components, and
	% corresponding quality status
	[indata]=loadnc(infile,components,0,start,chunksize);
	[quality]=loadnc(qfile,{'quality_status'},0,start,chunksize);

	% Compute white-sky albedo following Schaaf et al. 2002
	albvoldiffcoeff =  0.189184;
	albgeodiffcoeff = -1.377622;
	wsa = indata.isotropic + albvoldiffcoeff.*indata.volumetric +
	albgeodiffcoeff.*indata.geometric;
	
	% Optionally compute black-sky albedo at selected solar zenith
	% angles
	if do_bsa
	  szas=[0 75].*pi./180;
	  for isza=1:length(szas);
	    volcoeff = -0.007574 -0.070987.*szas(isza).^2 +
	    0.307588.*szas(isza).^3;
	    geocoeff = -1.284909 -0.166314.*szas(isza).^2 +
	    0.041840.*szas(isza).^3;
	    bsa{isza} = indata.isotropic + volcoeff.*indata.volumetric
	    + geocoeff.*indata.geometric;
	  end
	end

	% Optionally write out super-reflective pixels in the white-sky albedo
	[max_alb,index] = max(wsa(:));
	if max_alb > 1 & save_super_reflective
	  [iLat,iLon]=meshgrid(1:nchunk,1:nchunk);
	  lonind=iLon(index)+(ilonchunk-1)*nchunk;
	  latind=iLat(index)+(ilatchunk-1)*nchunk;
	  fprintf(fid,'%d %d %d %d %g %g %g %g %g %g %g\n',band,month,lonind,latind,...
		  indata.isotropic(index),indata.volumetric(index),indata.geometric(index),...
		  quality.quality_status(index),wsa(index),bsa{1}(index),bsa{2}(index));
	end

	% ...and super-reflective pixels in the black-sky albedo
	if do_bsa
	  [max_alb,index] = max(bsa{2}(:));
	  if max_alb > 1 & save_super_reflective
	    [iLat,iLon]=meshgrid(1:nchunk,1:nchunk);
	    lonind=iLon(index)+(ilonchunk-1)*nchunk;
	    latind=iLat(index)+(ilatchunk-1)*nchunk;
	    fprintf(fid,'%d %d %d %d %g %g %g %g %g %g %g\n',band,month,lonind,latind,...
		    indata.isotropic(index),indata.volumetric(index),indata.geometric(index),...
		    quality.quality_status(index),wsa(index),bsa{1}(index),bsa{2}(index));
	  end
	end

	% Convert to scaled integer and set status for missing data
	wsa = int16(min(wsa,1.0)./scale_factor);
	is_missing = find(isnan(indata.isotropic));
	wsa(is_missing) = -1;
	
	% Write white-sky albedo
	write_nc_var(ncid, 'wsa', wsa, start, chunksize);
	
	% Write black-sky albedo
	if do_bsa
	  bsa{1} = int16(bsa{1}./scale_factor);
	  bsa{1}(is_missing) = -1;
	  bsa{2} = int16(bsa{2}./scale_factor);
	  bsa{2}(is_missing) = -1;
	  write_nc_var(ncid, 'bsa0', bsa{1}, start, chunksize);
	  write_nc_var(ncid, 'bsa75', bsa{2}, start, chunksize);
	end
      end
    end
    % Close output file(s)
    netcdf.close(ncid);
    if save_super_reflective
      fclose(fid);
    end
  end
end
