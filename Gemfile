# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

gem 'pundit-resources',
    github: 'better-together-org/pundit-resources'

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'execjs'
  gem 'listen'
  gem 'pg'
  gem 'puma', '~> 6.0'
  gem 'rack-mini-profiler'
  gem 'rb-readline'
  gem 'rbtrace'
  gem 'rubocop'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.1.0'
  gem 'web-console', '>= 3.3.0'
end

group :development, :test do
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'byebug'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pry'
  gem 'rswag'
end

group :test do
  # gem 'capybara'
  # gem 'chromedriver-helper'
  gem 'coveralls'
  gem 'fuubar'
  gem 'rspec-rails'
  gem 'shoulda-callback-matchers'
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
  # gem 'selenium-webdriver'
end
