import csv
import sys
from pprint import pprint

def create_puma_dict():
	full_puma_dict = {"puma00_dict": {}, "puma10_dict": {}}

	with open("puma_dist_00.csv") as puma00csv, open("puma_dist_10.csv") as puma10csv:
		puma00dist, puma10dist = csv.reader(puma00csv), csv.reader(puma10csv)

		for i, r in enumerate((list(puma00dist), list(puma10dist))):
			puma_dict = {}
			counties = r[0][1:]

			for line in r[1:]:
				puma = line[0]

				if puma not in puma_dict:
					puma_dict[puma] = {}

				for county, proportion in enumerate(line[1:]):
					puma_dict[puma][counties[county]] = float(proportion)

			if i == 0:
				full_puma_dict["puma00_dict"] = puma_dict
			if i == 1:
				full_puma_dict["puma10_dict"] = puma_dict

	return full_puma_dict

def create_state_county_id_map(state):
	with open("state_county_ids.csv") as csv_file:
		r = list(csv.reader(csv_file))

		col_names = {r[0][i] : i for i in range(len(r[0]))}
		county_map = {}

		for row in r[1:]:
			if row[col_names["STATE_CODE"]] == state:
				county_map[row[col_names["COUNTY_NAME"]]] = int(row[col_names["COUNTY_ID"]].replace(",",""))
				state_id = row[col_names["STATE_ID"]]

	return (state_id, county_map)	

def generate_output(state, year):
	state_id, county_map = create_state_county_id_map(state)

	puma_dict = create_puma_dict()
	rounding_dict = {puma_type: {puma: {county: 0 for county in county_map.keys()} for puma, county_map in puma_map.items()} for puma_type, puma_map in puma_dict.items()}

	acs_file = "ss{0}p{1}.csv".format(year, state.lower())
	output_file = "p{0}{1}.csv".format(state.lower(), year)

	with open(acs_file) as acs_csv, open(output_file, "w") as w_csv:
		r, output = list(csv.reader(acs_csv)), csv.writer(w_csv)

		col_names = {r[0][i] : i for i in range(len(r[0][:-80]))}
		output.writerow(["PERSON_ID", "PERSON_CODE", "COUNTY_ID", "COUNTY_NAME", "STATE_ID", "STATE_CODE"] + r[0][:-80])
		cur_row = 1

		for row in r[1:]:
			pwgtp = int(row[col_names["PWGTP"]])
			
			if int(row[col_names["PUMA10"]]) < 0:
				puma = str(int(row[col_names["PUMA00"]]))
				puma_type = "puma00_dict"
				county_dict = puma_dict[puma_type][puma]
			else:
				puma = str(int(row[col_names["PUMA10"]]))
				puma_type = "puma10_dict"
				county_dict = puma_dict[puma_type][puma]

			for county, proportion in county_dict.items():
				num_rows = pwgtp * proportion
				round_rows = int(num_rows)

				[output.writerow([cur_row + i, state + str(cur_row + i), county_map[county], county, state_id, state] + row[:-80]) for i in range(round_rows)]
				
				cur_row += round_rows
				rounding_dict[puma_type][puma][county] += num_rows - round_rows

				if rounding_dict[puma_type][puma][county] >= 1:
					output.writerow([cur_row , state + str(cur_row), county_map[county], county, state_id, state] + row[:-80])
					rounding_dict[puma_type][puma][county] -= 1
					cur_row += 1

	return

state, year =  sys.argv[1], sys.argv[2]

generate_output(state, year)