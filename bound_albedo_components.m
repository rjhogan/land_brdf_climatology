% Ensure physical values for albedo components
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

function [iso_out,vol_out,geo_out,mask]=bound_albedo_components(iso,vol,geo);
  % Ensure albedo can never exceed 1 if solar zenith angle is less than 75 degrees
  sza=75.*pi./180;

  % Compute white- and black-sky albedos at 75 degree solar zenith
  % angle
  volcoeff = -0.007574 -0.070987.*sza.^2 +0.307588.*sza.^3;
  geocoeff = -1.284909 -0.166314.*sza.^2 +0.041840.*sza.^3;

  voldiffcoeff =  0.189184;
  geodiffcoeff = -1.377622;

  wsa = iso + voldiffcoeff.*vol + geodiffcoeff.*geo;
  bsa = iso + volcoeff.*vol     + geocoeff.*geo;

  % Copy inputs to outputs
  iso_out=iso;
  vol_out=vol;
  geo_out=geo;

  % Mask to indicate what corrections have been applied
  if nargout > 3
    mask=zeros(size(iso));
  end

  % Find unphysical white- or black-sky albedo - first when both are
  % larger than zero, in which case we have no alternative but to cap
  % at 1 for all solar zenith angles by setting the isotropic
  % component to 1 and the other two to zero
  index = find(wsa>1 & bsa>1);
  if ~isempty(index)
    iso_out(index)=1;
    vol_out(index)=0;
    geo_out(index)=0;
    mask(index)=3;
  end

  % If white-sky albedo is less than 1 but black-sky for 75 degrees is
  % greater: scale components to ensure it is exactly 1 at 75 degrees.
  index = find(wsa<=1 & bsa>1);
  if ~isempty(index)
    scaling = (1-wsa(index)) ./ (volcoeff.*vol(index)+geocoeff.*geo(index) - voldiffcoeff.*vol(index)-geodiffcoeff.*geo(index));
    geo_out(index) = geo(index).*scaling;
    vol_out(index) = vol(index).*scaling;
    iso_out(index) = wsa(index) - voldiffcoeff.*vol_out(index) - geodiffcoeff.*geo_out(index);
    mask(index)=1;
  end

  % Similar if white-sky albedo is greater than 1 but black-sky is not
  index = find(wsa>1 & bsa<=1);
  if ~isempty(index)
    scaling = (bsa(index)-1) ./ (volcoeff.*vol(index)+geocoeff.*geo(index) - voldiffcoeff.*vol(index)-geodiffcoeff.*geo(index));
    geo_out(index) = geo(index).*scaling;
    vol_out(index) = vol(index).*scaling;
    iso_out(index) = 1 - voldiffcoeff.*vol_out(index) - geodiffcoeff.*geo_out(index);
    mask(index)=2;
  end
