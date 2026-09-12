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

      has_many :federation_content_grants, as: :federatable, class_name: 'BetterTogether::FederationContentGrant',
                                           dependent: :destroy

      after_commit :notify_creator_of_federation_visibility_change, on: :update,
                                                                    if: :saved_change_to_federation_visibility?
    end

    class_methods do
      def extra_permitted_attributes
        super + [:federation_visibility, { federation_content_grants_by_connection: {} }]
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

    # Content-type key ('posts'/'pages'/'events') matching
    # PlatformConnectionFederationPolicy#allows_content_type? -- used to find
    # which active connections are even eligible for a per-connection grant.
    def federation_content_type_key
      self.class.name.demodulize.underscore.pluralize
    end

    # nil (no explicit grant -- defer to the tri-state) or 'allowed'/'denied'.
    def federation_grant_status_for(connection)
      federation_content_grants.find_by(platform_connection_id: connection.id)&.status
    end

    # Accepts { platform_connection_id => 'allowed'/'denied'/'platform_default' }.
    # 'platform_default' removes any existing grant for that connection rather
    # than persisting a redundant row.
    def federation_content_grants_by_connection=(grants_by_connection)
      return if grants_by_connection.blank?

      grants_by_connection.each do |connection_id, status|
        grant = federation_content_grants.find_or_initialize_by(platform_connection_id: connection_id)
        if status == 'platform_default'
          grant.destroy if grant.persisted?
        else
          grant.update!(status:)
        end
      end
    end

    private

    def notify_creator_of_federation_visibility_change
      return unless respond_to?(:creator) && creator.present?

      previous_visibility, current_visibility = saved_change_to_federation_visibility
      ::BetterTogether::FederationVisibilityStatusNotifier.with(
        record: self,
        federatable: self,
        previous_visibility:,
        current_visibility:
      ).deliver_later(creator)
    end
  end
end
