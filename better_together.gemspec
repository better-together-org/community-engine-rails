# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'better_together/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'better_together'
  spec.version     = BetterTogether::VERSION
  spec.authors     = ['Robert JJ Smith']
  spec.email       = ['rob@bettertogethersolutions.com']
  spec.summary     = 'The Better Together Community Engine allows people and organizations to build community.'
  spec.description = 'This project serves as the core of the Better Together community network'
  spec.license     = 'GNU LGPLV3'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'TODO: Set to http://mygemserver.com'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushespec.'
  end

  spec.required_ruby_version = '>= 3.2' # rubocop:todo Gemspec/RequiredRubyVersion

  spec.files = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']

  spec.add_dependency 'activerecord-import'
  spec.add_dependency 'activerecord-postgis-adapter'
  spec.add_dependency 'active_storage_svg_sanitizer'
  spec.add_dependency 'active_storage_validations'
  spec.add_dependency 'bootstrap', '~> 5.3.2'
  spec.add_dependency 'dartsass-sprockets', '~> 3.1'
  spec.add_dependency 'devise'
  spec.add_dependency 'devise-i18n'
  spec.add_dependency 'devise-jwt'
  spec.add_dependency 'elasticsearch-model', '~> 7'
  spec.add_dependency 'elasticsearch-rails', '~> 7'
  spec.add_dependency 'font-awesome-sass', '~> 6.5'
  spec.add_dependency 'friendly_id', '>= 5.2', '< 5.6'
  spec.add_dependency 'friendly_id-mobility', '~> 1.0.4'
  spec.add_dependency 'geocoder'
  spec.add_dependency 'groupdate'
  spec.add_dependency 'humanize_boolean'
  spec.add_dependency 'i18n-timezones'
  spec.add_dependency 'image_processing', '~> 1.2'
  spec.add_dependency 'importmap-rails', '~> 2.0'
  spec.add_dependency 'jsonapi-resources', '>= 0.10.0'
  spec.add_dependency 'kaminari'
  spec.add_dependency 'memory_profiler'
  spec.add_dependency 'mobility', '>= 1.0.1', '< 2.0'
  spec.add_dependency 'mobility-actiontext', '~> 1.1'
  spec.add_dependency 'noticed'
  spec.add_dependency 'premailer-rails'
  spec.add_dependency 'public_activity'
  spec.add_dependency 'pundit', '>= 2.1', '< 2.6'
  spec.add_dependency 'pundit-resources'
  spec.add_dependency 'rack-attack'
  spec.add_dependency 'rack-cors', '>= 1.1.1', '< 3.1.0'
  spec.add_dependency 'rack-mini-profiler'
  spec.add_dependency 'rails', '>= 7.2', '< 8.1'
  spec.add_dependency 'reform-rails', '>= 0.2', '< 0.4'
  spec.add_dependency 'rswag', '>= 2.3.1', '< 2.17.0'
  spec.add_dependency 'ruby-openai'
  spec.add_dependency 'simple_calendar'
  spec.add_dependency 'sitemap_generator'
  spec.add_dependency 'sprockets-rails'
  spec.add_dependency 'stackprof'
  spec.add_dependency 'stimulus-rails', '~> 1.3'
  spec.add_dependency 'storext'
  spec.add_dependency 'translate_enum'
  spec.add_dependency 'turbo-rails', '~> 2.0'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
