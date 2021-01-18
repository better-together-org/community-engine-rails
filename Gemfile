source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem 'pundit-resources',
    github: 'better-together-org/pundit-resources'

gemspec

group :development, :test do
  gem 'byebug'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pry'
  gem 'rswag'
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
