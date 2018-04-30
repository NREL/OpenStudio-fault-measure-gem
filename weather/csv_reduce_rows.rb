
require 'csv'

# load in csv file
file_name = "FRP2-2_DataWeather_Aug_Sep_2017.csv"
csv_data = CSV.read(file_name)
puts "#{file_name} has #{csv_data.size} rows."

# index of last header rows, first row is 0(will not be altered)
header = 3

# number of rows to be combined
rows_per_set = 60

# na - no change to value
# clear - value is removed
# avg - values are averaged
# sum - values are summed
# azimuth - average azimuth is calculated
# todo - come up with avarage azimith from collection of values (also not included direction values when speed is 0)
col_rules = ["na","clear","avg","avg","avg","avg","avg","avg","avg","na","na","avg","sum","avg","azimuth","clear","na"]

# write a new CSV file
file_out_name = "reduced.csv"
CSV.open(file_out_name, "wb") do |csv|
	csv_data[0..header].each do |row|
		csv << row
	end

	# set the current row of loop
	num_sets = ((csv_data.size-header)/rows_per_set.to_f).truncate
	puts "the data represents #{num_sets} complete sets."
	current_row = header + 1

	num_sets.times.each do |set|
		set_array = []
		col_rules.each do |rule|
			# todo - for azimuth I should add an array with two zeros
			if rule == "azimuth"
				set_array << {"x" => 0.0, "y" => 0.0}
			else
				set_array << 0.0 # adding pace holder values
			end
		end
		csv_data[current_row..(current_row+rows_per_set-1)].each do |row|

			row.each_with_index do |col,i|
				if col_rules[i] == "na"
					set_array[i] = col # everything is overwritten and last value sticks
				elsif col_rules[i] == "clear"
					set_array[i] = "" # pass an empty string in
				elsif col_rules[i] == "sum"
					set_array[i] += col.to_f
				elsif col_rules[i] == "azimuth"
					# rough method to calculate average angle
					# after adding values for each entry in set, calculate an azimuth at end of set loop
					next if not row[13].to_f > 0.0 # special use case to exclude azimuth when wind speed is 0
					radians = col.to_f * Math::PI / 180 
				    set_array[i]["x"] += Math.cos(radians)
				    set_array[i]["y"] += Math.sin(radians)
				else # avg
					set_array[i] += (col.to_f/rows_per_set)
				end

			end

		end

		# calculate azimuth values
		set_array.each_with_index do |col,i|
			if col_rules[i] == "azimuth"
				# relplace x and y values with azimuth
				avg_radians = Math.atan2(col["y"],col["x"])
				avg_degrees = avg_radians * 180 / Math::PI
				# EnergyPlus expects a value between 0-360
				if avg_degrees < 0 then avg_degrees += 360 end
				set_array[i] = avg_degrees
			end
		end

		# add reduced row to csv
		csv << set_array

		# udpate counter
		current_row += rows_per_set

	end

end

# report out size of reduced csv
puts "reduced.csv has #{CSV.read(file_out_name).size} rows."