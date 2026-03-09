# frozen_string_literal: true

namespace :docs do
  desc 'Run Capybara-driven documentation screenshot specs'
  task screenshots do
    ENV['RUN_DOCS_SCREENSHOTS'] = '1'
    sh 'bundle exec rspec spec/docs_screenshots --format documentation'
  end
end
