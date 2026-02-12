# frozen_string_literal: true

# !/usr/bin/env rake
begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'bundler/gem_tasks'

APP_RAKEFILE = File.expand_path('spec/dummy/Rakefile', __dir__)
load 'rails/tasks/engine.rake'

Bundler::GemHelper.install_tasks

require 'rdoc/task'

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'BetterTogether'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.md')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

load 'rails/tasks/statistics.rake'

Dir[File.join(File.dirname(__FILE__), 'tasks/**/*.rake')].each { |f| load f }
Dir[File.join(File.dirname(__FILE__), 'lib/tasks/**/*.rake')].each { |f| load f }

require 'rspec/core'
require 'rspec/core/rake_task'

# Load rswag rake tasks for API documentation generation
begin
  require 'rswag/specs/rake_task'

  # Define the swaggerize task with our custom pattern
  RSwag::Specs::RakeTask.new('rswag:specs:swaggerize') do |t|
    # Include only integration specs which have the rswag 'path' DSL
    t.pattern = 'spec/integration/**/api/**/*_spec.rb'
    # Remove --dry-run to actually execute the specs
    t.rspec_opts = ['--format', 'Rswag::Specs::SwaggerFormatter', '--order', 'defined']
    t.dry_run = false
  end
rescue LoadError
  # rswag not available
end

desc 'Run all specs in spec directory (excluding plugin specs)'
RSpec::Core::RakeTask.new(spec: 'app:db:test:prepare')

task default: :spec
