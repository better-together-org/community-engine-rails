# Better Together Community Engine

[➡️ View the Documentation Index](docs/README.md)

## Overview

<!-- SCREENSHOT: name=readme device=desktop spec=spec/docs_screenshots/readme_spec.rb:1 -->
![README (desktop)](screenshots/desktop/readme.png)

<!-- SCREENSHOT: name=readme device=mobile spec=spec/docs_screenshots/readme_spec.rb:1 -->
![README (mobile)](screenshots/mobile/readme.png)

The Better Together Community Engine is a transformative platform designed to unite communities through the power of collaboration and shared resources. Our core intention is to provide an inclusive, accessible space where individuals and groups from diverse backgrounds can come together to share knowledge, engage in meaningful dialogue, and develop innovative solutions to common challenges. By leveraging the collective wisdom and experience of its members, the platform aims to foster a culture of mutual support, learning, and sustainable growth.

At the heart of our mission lies the commitment to empower communities. We believe that by facilitating connections and encouraging collaboration, we can unlock the immense potential within communities to drive positive change. The platform is more than just a tool for communication; it's a hub for inspiration, a catalyst for innovation, and a foundation for building stronger, more resilient communities. Whether it's addressing environmental concerns, promoting social welfare, or supporting economic development, the Better Together Community Engine is dedicated to creating a brighter, more connected future for all.

This project embodies our vision of a world where collaboration leads to greater understanding, innovation, and collective action. We invite you to join us in this journey, to contribute your unique perspectives and skills, and to be a part of a community that believes in the power of working better, together.

This project is the core community building portion of the Better Together platform.

## Documentation

For system overviews, flows, and diagrams, see the docs index:

- docs: docs/README.md
- Exchange (Joatu), Notifications, Models & Concerns, and more with Mermaid diagrams (PNG rendered).

## Dependencies

In addition to other dependencies, the Better Together Community Engine relies on Action Text and Action Storage, which are part of the Rails framework. These dependencies are essential for handling rich text content and file storage within the platform.

### Action Text
[Action Text](https://guides.rubyonrails.org/action_text_overview.html#installation) brings rich text content and editing to Rails. It includes a WYSIWYG editor for writing rich text content stored in a manner compatible with Rails applications.

To set up Action Text, run the following commands:

```bash
rails action_text:install
rails action_text:install:migrations
```

Ensure that you follow the guide linked above to fully configure Action Text in your host app, including adding the required css and JavaScript files for the Trix editor and Action Text.

### Active Storage
[Active Storage](https://guides.rubyonrails.org/active_storage_overview.html#setup) facilitates uploading files to a cloud storage service like Amazon S3, Google Cloud Storage, or Microsoft Azure Storage, and attaching those files to Active Record objects.

To set up Active Storage, run the following command:

```bash
rails app:active_storage:install
```

Ensure that you follow the guide linked above to fully configure Active Storage in your host app, including creating and configuring your `storage.yml` file and setting storage defaults for your environments.

### UUID Primary Keys

The community engine uses UUIDs as primary keys with all tables using `id` as their UUID primary key. To ensure that the Active Storage and Action Text migrations use uuid as the foreign keys for records, set the following configuration in your host app's `application.rb` file or an initializer.

```ruby
config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

## Installation

Add this gem to your Gemfile:

```ruby
gem 'better_together', '~> 0.8.0',
    github: 'better-together-org/community-engine-rails',
    branch: 'main'
```

Include `pundit_resources` in your Gemfile from our GitHub repository

```ruby
gem 'pundit-resources', git: 'https://github.com/better-together-org/pundit-resources.git', branch: 'main'
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

This gem is developed using Docker and Docker Compose. To get the app running, complete the following steps:

Build the application image using the docker convenience scripts:

```bash
bin/dc build
```

Bundle the gems:

```bash
bin/dc-run app bundle
```

Setup the database:

```bash
bin/dc-run app rails db:setup
```

Run the RSpec tests:

```bash
bin/dc-run app rspec
```

## Contributing

We welcome contributions from the community.

- Guidelines: See [CONTRIBUTING.md](CONTRIBUTING.md) for how to report issues, propose changes, and submit pull requests.
- Code of Conduct: See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for expectations of behavior in our community.

Thank you for helping make Better Together better for everyone.
