# frozen_string_literal: true

require File.expand_path('../../lib/better_together/version', __dir__)

Gem::Specification.new do |spec|
  spec.name = 'better_together-borgberry'
  spec.version = BetterTogether::VERSION
  spec.authors = ['Robert JJ Smith']
  spec.email = ['rob@bettertogethersolutions.com']
  spec.summary = 'Optional C3 Tree Seeds + Borgberry fleet extension for Better Together Community Engine'
  spec.description = 'Provides the C3 community-contribution-token system, its federation token-seed ' \
                     'layer, the Joatu settlement bridge, and Borgberry fleet-node compute-contribution ' \
                     'tracking as an optional, non-bundled Community Engine extension.'
  spec.license = 'GNU LGPLV3'
  spec.required_ruby_version = '= 3.4.4'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['{app,lib,db}/**/*', '*.gemspec', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'better_together', spec.version
end
