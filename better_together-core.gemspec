$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "better_together/core/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "better_together-core"
  spec.version     = BetterTogether::Core::VERSION
  spec.authors     = ["Robert Smith"]
  spec.email       = ["rsmithlal@gmail.com"]
  spec.summary     = "The core of the Better Together project"
  spec.description = "This project serves as a common base for all of the subcomponents of Better Together"
  spec.license     = "GNU"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushespec."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 5.2.2"
  spec.add_dependency 'friendly_id', '~> 5.2.0'

  spec.add_development_dependency "pg"
  spec.add_development_dependency 'better_errors'
  spec.add_development_dependency 'binding_of_caller'
  spec.add_development_dependency 'byebug'

  spec.add_development_dependency 'execjs'
  spec.add_development_dependency 'listen'
  spec.add_development_dependency 'puma', '~> 3.11'
  spec.add_development_dependency 'rack-mini-profiler'
  spec.add_development_dependency 'rb-readline'
  spec.add_development_dependency 'rbtrace'
  spec.add_development_dependency 'rubocop'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  spec.add_development_dependency 'spring'
  spec.add_development_dependency 'spring-watcher-listen', '~> 2.0.0'
  spec.add_development_dependency 'web-console', '>= 3.3.0'
end
