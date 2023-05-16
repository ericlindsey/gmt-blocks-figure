#!/bin/bash

# Check if the input parameters are correct
if [ "$#" -ne 7 ]; then
  echo "Usage: $0 west east south north resolution azimuth normalization"
  echo "The resolution should be one of the available options in GMT: e.g. 10m, 03m, 01m, 03s, 15s, 01s."
  exit 1
fi

# Input parameters
west=$1
east=$2
south=$3
north=$4
resolution=$5
azimuth=$6
normalization=$7

# Download DEM data
dem_file="dem_${resolution}.grd"
gmt grdcut @earth_relief_${resolution} -G${dem_file} -R${west}/${east}/${south}/${north} -V

# Compute gradient
dem_grad="dem_grad_${resolution}_${azimuth}_${normalization}.grd"
gmt grdgradient ${dem_file} -G${dem_grad} -A${azimuth} -Ne${normalization} -V

echo "DEM file: ${dem_file}"
echo "Gradient file: ${grad_file}"

