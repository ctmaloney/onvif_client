require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: [:spec, :rubocop]

desc "Run example usage script"
task :example do
  ruby "examples/usage.rb"
end

desc "Run IRB console with gem loaded"
task :console do
  require "irb"
  require "onvif_client"
  ARGV.clear
  IRB.start
end
