# frozen_string_literal: true

module BetterTogether
  # Represents a class that has control over the actions of other classes.
  # Meant to be used with user login classes
  module TrackedActivity
    extend ActiveSupport::Concern

    included do
      include PublicActivity::Model

      tracked owner: proc { |controller, _model| controller&.helpers&.current_person },
              # rubocop:todo Lint/UnderscorePrefixedVariableName
              privacy: proc { |_controller, _model| _model.privacy if _model.respond_to?(:privacy) }
      # rubocop:enable Lint/UnderscorePrefixedVariableName

      has_many :activities, as: :trackable, class_name: 'PublicActivity::Activity', dependent: :destroy
    end

    # Extensible API for determining if a trackable should appear in activity feeds
    # Models can override this method to implement custom visibility logic
    # @param user [User] the user viewing the activity feed
    # @return [Boolean] true if the trackable should appear in activity feeds for the given user
    def trackable_visible_in_activity_feed?(user)
      # Delegate to the model's policy using Pundit's safe policy resolution
      policy = Pundit.policy(user, self)
      policy&.show? || false
    end

    class_methods do
      def included_in_models
        Rails.application.eager_load! unless Rails.env.production? # Ensure all models are loaded
        ActiveRecord::Base.descendants.select { |model| model.included_modules.include?(BetterTogether::TrackedActivity) }
      end
    end
  end
end
