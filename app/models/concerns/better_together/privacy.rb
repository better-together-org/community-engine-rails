# frozen_string_literal: true

module BetterTogether
  # Concern that when included give the model privacy utilities
  module Privacy
    extend ActiveSupport::Concern

    PRIVACY_LEVELS = {
      public: 'public',
      community: 'community',
      private: 'private'
    }.freeze

    included do
      include ::TranslateEnum
      include PrivacyCeilingValidatable

      attribute :privacy, :string
      enum :privacy, PRIVACY_LEVELS, prefix: :privacy

      translate_enum :privacy

      validates :privacy, presence: true, inclusion: { in: PRIVACY_LEVELS.values }
      validate :require_publishing_agreement_for_public_visibility

      scope :privacy_public, -> { where(privacy: 'public') }
      scope :privacy_community, -> { where(privacy: 'community') }
      scope :privacy_private, -> { where(privacy: 'private') }
    end

    class_methods do
      def extra_permitted_attributes
        super + %i[privacy]
      end
    end

    def self.included_in_models
      included_module = self
      Rails.application.eager_load! unless Rails.env.production? # Ensure all models are loaded
      ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
    end

    private

    def require_publishing_agreement_for_public_visibility
      return unless privacy_public? || privacy_community?
      return unless new_record? || will_save_change_to_privacy?
      # External and federated-mirror records carry a privacy decision made
      # elsewhere; the origin already ran this gate. See PrivacyCeilingValidatable.
      return if externally_governed_privacy?

      BetterTogether::PublicVisibilityGate.allow!(
        record: self,
        actor: Current.agent,
        target_privacy: privacy
      )
    end

    def externally_governed_privacy?
      (respond_to?(:external?) && external?) || (respond_to?(:mirrored?) && mirrored?)
    end
  end
end
