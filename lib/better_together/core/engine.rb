module BetterTogether
  module Core
    class Engine < ::Rails::Engine
      isolate_namespace BetterTogether::Core

      config.generators do |g|
        g.test_framework :rspec
        g.fixture_replacement :factory_bot, :dir => 'spec/factories'
      end

      config.before_initialize do
        require 'friendly_id'
        require 'mobility'
      end
    end
  end
end
