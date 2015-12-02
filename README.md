# Census Transformer

## Description
This program transforms ACS census data files to a ready to upload to vertica csv.

Each row in the ACS data contains a variable PWGTP, or person weight, and matches to a PUMA, or public use micro area, of at least 100,000 people.
We duplicate the rows by their weight and assign each duplicate a unique identifier and a county based on the proportion of the PUMA in that county.
Data for before 2012 has a PUMA00 code while data during or after 2012 uses a PUMA10 code. This is because PUMAs were redefined at this time.

There are five datasets besides the ACS data used to accomplish this:

## Files
2010_Census_Tract_to_2010_PUMA.txt: State - Census Tract - Puma10: https://www.census.gov/geo/maps-data/data/centract_rel.html

us2010trf.txt: Census Tract - Pop: https://www.census.gov/geo/maps-data/data/tract_rel_download.html
	headers: https://www.census.gov/geo/maps-data/data/tract_rel_layout.html

national_county.txt: State Name - State FIPS - County FIPS - County Name: https://www.census.gov/geo/reference/codes/cou.html

puma2k_puma2010.csv: State - puma00 - puma10 - proportion of puma10 in puma00: http://mcdc.missouri.edu/data/corrlst/puma2k_puma2010.csv

	!!NOTE (If downloading from site): must remove second row (the detailed descriptions) for script to work!!

state_county_ids.csv: Custom State ID - State - Custom County ID - County

NewPumaDist.R: generates the puma to county distributions for use in duplicating the census data. 

transform_acs.py: reads the acs file and generates the transformed dataset.

## Using the script:
Download the ACS file you want to transform (e.g. ss13pnh for 2013 5-year data for new hampshire) to the same directory
Run the R file NewPumaDist.R. It will ask for a 2 digit year and state abbrevation or state fips code. 

If you want to hold your acs files in a different directory, you need to alter the read in generate_output in the python file and generate_final_output in the R file.