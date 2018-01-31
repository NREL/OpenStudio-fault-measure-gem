require 'fileutils'

# get resource files
shared_resource_files = Dir.glob("shared_resources/*.*")
measures = Dir.glob("fault_measures_2017/**/resources/*.rb")

# loop through shared resoruce files and copy to measures
puts ""
puts "copying shared resource files to measures"
shared_resource_files.each do |shared_resource|
	# loop through measure dirs looking for matching file
	measures.each do |measure_resource|
		next if not File.basename(measure_resource) == File.basename(shared_resource)
		puts "Replacing #{measure_resource} with #{shared_resource}."
		FileUtils.cp(shared_resource, File.path(measure_resource))
	end
end

# get test models
shared_test_models = Dir.glob("shared_test_models/*.*")
test_models = Dir.glob("fault_measures_2017/**/tests/*.osm")

# loop through shared test models and copy to measures
puts ""
puts "copying shared test models to measures"
shared_test_models.each do |shared_test|
	# loop through measure dirs looking for matching file
	test_models.each do |measure_test|
		next if not File.basename(measure_test) == File.basename(shared_test)
		puts "Replacing #{measure_test} with #{shared_test}."
		FileUtils.cp(shared_test, File.path(measure_test))
	end
end