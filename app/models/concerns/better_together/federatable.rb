# frozen_string_literal: true

module BetterTogether
  # Concern that gives a model a per-item federation-visibility override,
  # layered on top of the connection-level (PlatformConnectionFederationPolicy)
  # and creator-level (Person#federate_content) consent gates.
  module Federatable
    extend ActiveSupport::Concern

    FEDERATION_VISIBILITY_LEVELS = {
      platform_default: 'platform_default',
      federate: 'federate',
      no_federate: 'no_federate'
    }.freeze

    included do
      include ::TranslateEnum

      attribute :federation_visibility, :string
      enum :federation_visibility, FEDERATION_VISIBILITY_LEVELS, prefix: :federation_visibility

      translate_enum :federation_visibility

      validates :federation_visibility, presence: true, inclusion: { in: FEDERATION_VISIBILITY_LEVELS.values }

      scope :federation_visibility_default, -> { where(federation_visibility: 'platform_default') }
      scope :federation_opted_in, -> { where(federation_visibility: 'federate') }
      scope :federation_opted_out, -> { where(federation_visibility: 'no_federate') }
    end

    class_methods do
      def extra_permitted_attributes
        super + %i[federation_visibility]
      end
    end

    def self.included_in_models
      included_module = self
      Rails.application.eager_load! unless Rails.env.production? # Ensure all models are loaded
      ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
    end

    # True when this item overrides the platform/creator default federation
    # behavior in either direction (explicit opt-in or hard opt-out).
    def federation_visibility_override?
      federation_visibility_federate? || federation_visibility_no_federate?
    end
  end
end
