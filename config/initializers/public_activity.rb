# frozen_string_literal: true

# config/initializers/public_activity.rb

# require 'better_together/privacy'

ActiveSupport::Reloader.to_prepare do
  PublicActivity::Config.set do
    table_name 'better_together_activities'
  end

  # PublicActivity::Activity.include BetterTogether::Privacy
  PublicActivity::Activity.class_eval do
    def self.policy_class
      BetterTogether::ActivityPolicy
    end
  end
end
