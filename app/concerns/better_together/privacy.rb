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
      enum privacy: PRIVACY_LEVELS,
           _prefix: :privacy
    end
  end
end
