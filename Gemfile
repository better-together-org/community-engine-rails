source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

group :development, :test do
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pry'
end

group :test do
  gem 'capybara', '>= 2.15'
  gem 'chromedriver-helper'
  gem 'coveralls'
  gem 'fuubar'
  gem 'rspec-rails'
  gem 'shoulda-callback-matchers'
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
  gem 'selenium-webdriver'
end
