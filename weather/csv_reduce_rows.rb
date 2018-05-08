
require 'csv'

# load in csv file
file_name = "FRP2-2_DataWeather_Aug_Sep_2017_clean.csv"
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

# approach perscribed by ornl was last value for temps and hr, avg for air pressure
#col_rules = ["last","time","avg","avg","avg","avg","avg","avg","avg","last","last","avg","sum","avg","azimuth","clear","last"]

# changes made from perscribed path
# set air pressure to avg matching temp and humidity inputs
# shifted the date/time to the first vs. last row from each averging group
col_rules = ["date","time","last","last","last","last","last","last","last","last","last","last","sum","last","azimuth","clear","last"]
#col_rules = ["date","time","avg","avg","avg","avg","avg","avg","avg","avg","avg","avg","sum","avg","azimuth","clear","avg"]

# todo - coud be nice to avg 30 minutes before and after the time, or maybe even jsut 7 minutes each side to get 15min window
# todo - or update this to use 15 minute timestep maching simulation so no weather file interpolation.

# write a new CSV file
file_out_name = "FRP2-2_DataWeather_Aug_Sep_2017_clean_reduced.csv"
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
		csv_data[current_row..(current_row+rows_per_set-1)].each_with_index do |row,j|

			# separate date and time
			space_index = row[0].to_s.index(" ")
			date = row[0].to_s[0..space_index-1]
			time = row[0].to_s[space_index+1..row[0].size]

			row.each_with_index do |col,i|
				if col_rules[i] == "last"
					set_array[i] = col # everything is overwritten and last value sticks
				elsif col_rules[i] == "clear"
					set_array[i] = "" # pass an empty string in
				elsif col_rules[i] == "first"
					# only set date once for the first row
					if j == 0 then set_array[i] = col end
				elsif col_rules[i] == "date"
					# only set date once for the first row
					if j == 0 then set_array[i] = date end
				elsif col_rules[i] == "time"
					# only set date once for the first row
					if j == 0 then set_array[i] = time end
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