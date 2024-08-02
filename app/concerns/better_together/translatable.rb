# frozen_string_literal: true

module BetterTogether
  # Concern that when included makes the model act as an identity
  module Translatable
    extend ActiveSupport::Concern

    included do
      extend Mobility

      scope :with_translations, -> { includes(:string_translations, :text_translations) }
    end
  end
end
