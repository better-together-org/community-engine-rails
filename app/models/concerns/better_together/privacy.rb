# frozen_string_literal: true

module BetterTogether
  # Concern that when included give the model privacy utilities
  module Privacy
    extend ActiveSupport::Concern

    PRIVACY_LEVELS = {
      public: 'public',
      private: 'private',
      unlisted: 'unlisted'
    }.freeze

    included do
      include ::TranslateEnum

      attribute :privacy, :string
      enum privacy: PRIVACY_LEVELS,
           _prefix: :privacy

      translate_enum :privacy

      validates :privacy, presence: true, inclusion: { in: PRIVACY_LEVELS.values }

      scope :privacy_public, -> { where(privacy: 'public') }
      scope :privacy_private, -> { where(privacy: 'private') }
    end

    class_methods do
      def extra_permitted_attributes
        super + %i[privacy]
      end
    end
  end
end
