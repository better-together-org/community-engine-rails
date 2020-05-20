module BetterTogether
  class Engine < ::Rails::Engine
    isolate_namespace BetterTogether

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, :dir => 'spec/factories'
    end

    config.before_initialize do
      require 'friendly_id'
      require 'mobility'
      require 'friendly_id/mobility'
    end
  end
end
