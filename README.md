# Better Together Community Engine

[![Build Status](https://travis-ci.com/better-together-org/community-engine-rails.svg?branch=production)](https://travis-ci.com/better-together-org/community-engine-rails)

This project is the core community building portion of the Better Together platform.

## Installation

Add gem to your Gemfile:

``` ruby
gem 'better_together', '~> 0.3.1',
    github: 'better-together-org/community-engine-rails'
```
Run the engine installer. This will create an initializer to allow you to customize the engine, such as setting your own user class.

```bash
rails g better_together:install
```

Install the migrations. This will run a rake task to copy over the migrations from the better_together engine.

```bash
rails better_together:install:migrations
```

Run the migrations. This will set up the database tables required to run the better_together engine.

```bash
rails db:migrate
```

## Development: Getting Started

This gem is developed using Docker and Docker Compose. In order to get the app running, you must complete the following steps:

- Build the application image: `docker compose build`
- Bundle the gems: `docker compose run app bundle`
- Bundle the gems: `docker compose run app rails db:setup`
- Run the rspec tests `docker compose run app bundle exec rspec`
