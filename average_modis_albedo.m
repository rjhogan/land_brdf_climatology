% This script averages up MODIS albedo from daily files into monthly
% files, but averaging by quality flag
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

% Where will the intermediate data from this step be stored
outdir = [intermediate_base_dir '/averaged'];
if ~exist(outdir,'dir')
  mkdir(intermediate_base_dir,'averaged');
end

% Number of quality groups to output
nqual = length(qualities);

% Loop over requested bands
for iband=1:length(bands)
  band=bands(iband);

  % Loop over requested months
  for imon=1:length(months)
    month=months(imon);

    % Loop over components
    for icomp=1:length(components)
      component=components{icomp};

      % Loop over qualities
      for iq=1:nqual
	qual=qualities{iq};

	% Create an output file for this component/band/month/quality
	% and store its ID. We use HDF4 files for intermediate
	% quantities because it is them easier to match the chunking
	% of the input HDF4 files and by processing a chunk at a time
	% we avoid the need to load multiple huge files into memory at
	% once.
	basename=[outdir '/MCD43GF_' component '_' band_names{band} '_mon' num2str(month,'%02d') ...
			 '_' num2str(years(1)) '-' num2str(years(end)) '_qa' num2str(qual(1)) '-' ...
			 num2str(qual(2))];
	outid(iq) = create_hdf4_file([basename '_average.hdf']);

	% Create an output file for this band/month/quality to store
	% the number of days contained in the average.
	if icomp == 1
	  basename=[outdir '/MCD43GF_' band_names{band} '_mon' num2str(month,'%02d') '_' ...
			   num2str(years(1)) '-' num2str(years(end)) '_qa' num2str(qual(1)) ...
			   '-' num2str(qual(2))];
	  countid(iq) = create_hdf4_file([basename '_count.hdf']);
	end
      end

      % Loop over longitude and latitude chunks
      for ilon = 1:nlon
	for ilat = 1:nlat

	  % 0-based chunk location
	  location=[ilon-1 ilat-1];

	  % Initialize cumulative sum and number of samples
	  cumdata=zeros([chunksize nqual]);
	  counts =zeros([chunksize nqual]);

	  % Loop over years
	  for iyear=1:length(years)
	    year = years(iyear);

	    % Length of months for this year, including leap year exception
	    month_lengths = [31 28 31 30 31 30 31 31 30 31 30 31];
	    if mod(year,4) == 0
	      month_lengths(2) = 29;
	    end
	    
	    % Julian day for the start and end of each month
	    cum_month = cumsum(month_lengths);
	    month_end = cum_month(month);
	    month_start=month_end-month_lengths(month)+1;

	    % List of Julian days for this month
	    days = month_start:month_end;

	    % Bad data on 1 Jan 2020 for the "VIS" channel: exclude it
	    start_day = 1;
	    if year == 2020 & do_vis_nir & month == 1 %& band == 1
	      start_day = 2;
	    end
	    
	    % Loop over good days
	    for iday = start_day:length(days)
	      day = days(iday);

	      % Load a chunk (specified by "location") of quality
	      % assurance data for year/band/day
	      qa = load_hdf4_chunk([input_base_dir '/' num2str(year) '/MCD43GF_qa_' band_names{band} ...
					     '_' num2str(day,'%03d') '_' num2str(year) ...
					     '_V061.hdf'],location);

	      % Load an albedo component, noting that it will be
	      % stored as an integer corresponding to 100x the actual
	      % value
	      [data,fillvalue]=load_hdf4_chunk([input_base_dir '/' num2str(year) '/MCD43GF_' component ...
							 '_' band_names{band} '_' num2str(day,'%03d') ...
							 '_' num2str(year) '_V061.hdf'],location);
	      
	      % Loop over quality groups and add the data to the
	      % cumulative sum and increment the counts
	      for iq=1:nqual
		datamask = zeros(size(data));
		index=find(data ~= fillvalue & qa>=qualities{iq}(1) & qa<=qualities{iq}(2));
		datamask(index)=double(data(index));
		cumdata(:,:,iq)=cumdata(:,:,iq)+datamask;
		datamask(index)=1;
		counts(:,:,iq)=counts(:,:,iq)+datamask;
	      end
	    end
	  end

	  % Convert the cumulative sums to means by dividing by the
	  % counts
	  index = find(counts>0);
	  cumdata(index)=cumdata(index)./counts(index);

	  % Write chunk of data and counts
	  disp(['Writing chunk ' num2str(location)]);
	  for iq=1:nqual
	    % Store at 10x the precision of the original data, so we
	    % will be storing integers representing 0.001x the
	    % original data
	    write_hdf4_chunk(outid(iq), location, int16(cumdata(:,:,iq).*10));
	    if icomp == 1
	      write_hdf4_chunk(countid(iq), location, int16(counts(:,:,iq)));
	    end
	  end
	end
      end

      % Close file
      for iq=1:nqual
	close_hdf4_file(outid(iq));
	if icomp == 1
	  close_hdf4_file(countid(iq));
	end
      end
    end
  end
end
