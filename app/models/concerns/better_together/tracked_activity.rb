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

    def self.included_in_models
      Rails.application.eager_load! if Rails.env.development? # Ensure all models are loaded
      ActiveRecord::Base.descendants.select { |model| model.included_modules.include?(BetterTogether::TrackedActivity) }
    end
  end
end
