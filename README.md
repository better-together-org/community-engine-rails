# Better Together Community Engine

[![Build Status](https://travis-ci.com/better-together-org/community-engine-rails.svg?branch=production)](https://travis-ci.com/better-together-org/community-engine-rails)
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fbetter-together-org%2Fcommunity-engine.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Fbetter-together-org%2Fcommunity-engine?ref=badge_shield)

This project is the core community building portion of the Better Together platform.

## Installation

Add gem to your Gemfile:

``` ruby
gem 'better_together', '~> 0.1.0',
    github: 'better-together-org/community-engine-rails'
```
Run the engine installer. This will create an initializer to allow you to customize the engine, such as setting your own user class.

```bash
rails g better_together:install
```

## Development: Getting Started

This gem is developed using Docker and Docker Compose. In order to get the app running, you must complete the following steps:

- Build the application image: `docker-compose build`
- Bundle the gems: `docker-compose run app bundle`
- Run the rspec tests `docker-compose run app bundle exec rspec`


## Class Model

### Person

### Group

### Invitation

###  Membership

### Role

## Interfaces

### Joinable

### Member

### Invitable


## License
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fbetter-together-org%2Fcommunity-engine.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Fbetter-together-org%2Fcommunity-engine?ref=badge_large)
