% This script merges MODIS albedo monthly averages with different
% quality levels and from adjacent months, in order that the final
% climatology averages at least a certain number of days
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

% Input and output directories
indir =[intermediate_base_dir '/averaged'];
outdir=[intermediate_base_dir '/merged'];
if ~exist(outdir,'dir')
  mkdir(intermediate_base_dir,'merged');
end

% Coefficients to create the diffuse (white-sky) albedo
albvoldiffcoeff =  0.189184;
albgeodiffcoeff = -1.377622;

% Number of quality groups to process
nqual = length(qualities);

% Minimum number of days needed for a given monthly average
min_days = length(years).*min_days_per_month;

% Loop over bands
for iband=1:length(bands)
  band=bands(iband);

  % Loop over months
  for imon=1:length(months)
    month=months(imon);

    % Create quality status output file for this band/month
    basename=[outdir '/MCD43GF_' band_names{band} '_mon' num2str(month,'%02d') '_' num2str(years(1)) '-' num2str(years(end))];
    statusid(imon) = create_hdf4_file([basename '_status.hdf']);
  end

  % Loop over albedo components
  for icomp=1:1:length(components)
    component=components{icomp};

    % Create output files per month and component
    for imon=1:length(months)
      month=months(imon);
      basename=[outdir '/MCD43GF_' component '_' band_names{band} '_mon' num2str(month,'%02d') '_' num2str(years(1)) '-' num2str(years(end))];
      outid(imon,icomp) = create_hdf4_file([basename '.hdf']);
    end
    
  end

  % Loop over longitude and latitude chunks
  for ilon = 1:nlon
    for ilat = 1:nlat

      % 0-based chunk location
      location=[ilon-1 ilat-1];

      % Initialize data to store everything for one chunk: all quality
      % groups, all months and all components
      data=zeros([chunksize nqual 12 length(components)]);

      % Initialize day count for one chunk, all quality groups, all
      % months
      counts=zeros([chunksize nqual 12]);

      % Loop over quality groups
      for iq=1:nqual
	qual=qualities{iq};

	% Loop over months
	for imon=1:length(months)
	  month=months(imon);

	  % Load count of days for a given month and quality group
	  basename=[indir '/MCD43GF_' band_names{band} '_mon' num2str(month,'%02d') '_' ...
			  num2str(years(1)) '-' num2str(years(end)) '_qa' num2str(qual(1)) '-' num2str(qual(2))];
	  counts(:,:,iq,imon) = load_hdf4_chunk([basename '_count.hdf'],location);

	  % Loop over albedo components
	  for icomp=1:1:length(components)
	    component=components{icomp};

	    % Load the averaged data for a given component, quality
	    % group and month
	    basename=[indir '/MCD43GF_' component '_' band_names{band} '_mon' num2str(month,'%02d') '_' ...
			    num2str(years(1)) '-' num2str(years(end)) '_qa' num2str(qual(1)) '-' num2str(qual(2))];
	    data(:,:,iq,imon,icomp) = load_hdf4_chunk([basename '_average.hdf'],location);
	  end
	end
	
      end

      % Blank out negative white-sky albedos
      for imon=1:length(months)
	for iq=1:nqual
	  wsa_is_positive = (data(:,:,iq,imon,1) ...
			     + albvoldiffcoeff.*data(:,:,iq,imon,2) ...
			     + albgeodiffcoeff.*data(:,:,iq,imon,3) >= 0.0);
	  nbad(iq)=length(find(wsa_is_positive==0));
	  counts(:,:,iq,imon) = counts(:,:,iq,imon) .* wsa_is_positive;
	end
	disp(['Month ' num2str(imon) ': number of wsa<0 pixels by quality: ' num2str(nbad)]);
      end

      % Loop over month
      for imon=1:length(months)

	% Merge the various quality groups
	disp(['Performing merge for month ' num2str(imon)])

	% The numbers in the following list are the quality "version"
	% indexed by iver, where a higher number is a worse quality
	
	% 0. Add best quality data: qa=0,1 same month
	for icomp = 1:length(components)
	  outdata{icomp}=squeeze(data(:,:,1,imon,icomp).*counts(:,:,1,imon));
	end
	outcounts=squeeze(counts(:,:,1,imon));

	% This variable keeps track of the cumulative sum of (iver+1),
	% such that we can get an estimate of the average quality of
	% the data that went into the average. Since we are starting
	% with the best quality with iver=0, its weight is equal to
	% 1*the number of counts.
	outstatus=outcounts;
	
	% Get a list of the pairs of months that are 1,2,3 etc. away
	% from the target month. So for if imon=1 (January) then
	% imon2{1} = {Dec,Feb}, imon2{2} = {Nov,Mar} etc.
	for imon2=1:6
	  altmon{imon2}=mod(imon+[-1 1].*imon2-1,12)+1;
	end
	
  	% Create a list of the order of quality groups and month
  	% separations to search through in order if not enough days
  	% are available with the best quality
	
	% 1. qa=2,3 same month
	qualind(1)=2;
	monind{1}=imon;
        % 2. qa=0,1 adjacent month
	qualind(2)=1;
	monind{2}=altmon{1};
	% 3. qa=2,3 adjacent month
	qualind(3)=2;
	monind{3}=altmon{1};
	% 4. qa=0,1 next month
	qualind(4)=1;
	monind{4}=altmon{2};
        % 5. qa=2,3 next month
	qualind(5)=2;
	monind{5}=altmon{2};
	% 6. qa=4+ same month
	qualind(6)=3;
	monind{6}=imon;
	% 7. qa=4+ adjacent month
	qualind(7)=3;
	monind{7}=altmon{1};
	% 8. qa=4+ next month
	qualind(8)=3;
	monind{8}=altmon{2};
	iver=9;
	for iimon=3:6
	  for iq=1:nqual
	    qualind(iver)=iq;
	    monind{iver}=altmon{iimon};
	    iver=iver+1;
	  end
	end

	% Loop over the list of descending quality selections
	for iver = 1:length(qualind)
	  iq = qualind(iver);
	  if length(monind{iver})==1
	    % Only one month present, probably exactly six months
	    % away; first add only as many days as are needed
	    nextcount=min(counts(:,:,iq,monind{iver}),max(0,min_days-outcounts));

	    % Sum each component weighted by the number of days needed
	    for icomp = 1:length(components)
	      outdata{icomp}=outdata{icomp}+data(:,:,iq,monind{iver},icomp).*nextcount;
	    end
	  else
	    % Two months present, e.g. if there was no data for Jan
	    % then we would look at {Dec,Feb}
	    tmpcount=counts(:,:,iq,monind{iver}(1))+counts(:,:,iq,monind{iver}(2));
	    nextcount=min(tmpcount,max(0,min_days-outcounts));
	    for icomp = 1:length(components)
	      tmpdata = (data(:,:,iq,monind{iver}(1),icomp).*counts(:,:,iq,monind{iver}(1)) ...
			 + data(:,:,iq,monind{iver}(2),icomp).*counts(:,:,iq,monind{iver}(2))) ...
			./ max(1,tmpcount);
	      outdata{icomp}=outdata{icomp}+tmpdata.*nextcount;
	    end
	  end

	  % Record total number of days accumulated for each spatial point
	  outcounts = outcounts+nextcount;

	  % Accumuate a weighted average of "iver+1", so that 
	  outstatus = outstatus + (iver+1).*nextcount;
	end

	% Recover the average version of "iver", noting that a -1 will
	% indicate that no data were found
	outstatus = round(outstatus./max(1,outcounts))-1;

	% Write it to the output file
	write_hdf4_chunk(statusid(imon), location, int16(outstatus));

	% Write the average of each component
	for icomp = 1:length(components)
	  write_hdf4_chunk(outid(imon,icomp), location, int16(outdata{icomp}./max(1,outcounts)));
	end
      end
    end
  end
  
  % Close the output files
  for imon = 1:length(months)
    close_hdf4_file(statusid(imon));
    for icomp = 1:length(components)
      close_hdf4_file(outid(imon,icomp));
    end
  end
end
