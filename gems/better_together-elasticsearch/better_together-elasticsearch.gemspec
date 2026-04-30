# frozen_string_literal: true

require File.expand_path('../../lib/better_together/version', __dir__)

Gem::Specification.new do |spec|
  spec.name = 'better_together-elasticsearch'
  spec.version = BetterTogether::VERSION
  spec.authors = ['Robert JJ Smith']
  spec.email = ['rob@bettertogethersolutions.com']
  spec.summary = 'Optional Elasticsearch extension for Better Together Community Engine'
  spec.description = 'Provides Elasticsearch client boot, indexing jobs, and search adapter wiring for Better Together.'
  spec.license = 'GNU LGPLV3'
  spec.required_ruby_version = '= 3.4.4'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['{app,lib}/**/*', '*.gemspec', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'better_together', spec.version
  spec.add_dependency 'elasticsearch-model', '~> 8'
  spec.add_dependency 'elasticsearch-rails', '~> 8'
end
