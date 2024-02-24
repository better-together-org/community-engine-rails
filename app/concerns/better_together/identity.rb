# frozen_string_literal: true

module BetterTogether
  # Concern that when included makes the model act as an identity
  module Identity
    extend ActiveSupport::Concern

    included do
      has_many :identifications,
               as: :identity
    end
  end
end
