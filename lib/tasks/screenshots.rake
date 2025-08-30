namespace :docs do
  desc 'Run documentation screenshot specs'
  task :screenshots do
    puts 'Running documentation screenshot specs...'
    ENV['RUN_DOCS_SCREENSHOTS'] = '1'

    # Run only specs under spec/docs_screenshots
    RSpec::Core::RakeTask.new(:docs_screenshots) do |t|
      t.pattern = 'spec/docs_screenshots/**/*_spec.rb'
      t.rspec_opts = ['--format', 'documentation']
    end

    Rake::Task['docs_screenshots'].invoke
  end
end
