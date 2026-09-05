# frozen_string_literal: true

# config/initializers/public_activity.rb

ActiveSupport::Reloader.to_prepare do
  PublicActivity::Config.set do
    table_name 'better_together_activities'
  end

  # Ensure the custom model's policy_class is accessible via the base class too.
  PublicActivity::Activity.class_eval do
    def self.policy_class
      BetterTogether::ActivityPolicy
    end
  end
end
