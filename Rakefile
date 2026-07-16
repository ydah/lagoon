# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

desc 'Validate RBS signatures'
task 'rbs:validate' do
  sh 'bundle exec rbs -I sig validate'
end

desc 'Compile every Ruby file'
task :syntax do
  ruby_files = FileList['lib/**/*.rb', 'exe/*', 'spec/**/*.rb', '*.gemspec', 'Rakefile']
  ruby_files.each { |file| RubyVM::InstructionSequence.compile_file(file) }
end

task default: %i[spec syntax rubocop rbs:validate build]
