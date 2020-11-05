require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'
RuboCop::RakeTask.new

# Load in the rake tasks from the base openstudio-extension gem
require 'openstudio/extension/rake_task'
require 'openstudio/fault_models'
os_extension = OpenStudio::Extension::RakeTask.new
os_extension.set_extension_class(OpenStudio::FaultModels::FaultModels)

task default: :spec
