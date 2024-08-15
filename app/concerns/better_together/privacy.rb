# frozen_string_literal: true

module BetterTogether
  # Concern that when included give the model privacy utilities
  module Privacy
    extend ActiveSupport::Concern

    PRIVACY_LEVELS = {
      secret: 'secret',
      closed: 'closed',
      public: 'public'
    }.freeze

    included do
      include TranslateEnum

      enum privacy: PRIVACY_LEVELS,
           _prefix: :privacy

      translate_enum :privacy

      validates :privacy, presence: true, inclusion: { in: PRIVACY_LEVELS.values }

      scope :privacy_public, -> { where(privacy: 'public') }
    end
  end
end
