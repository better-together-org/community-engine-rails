# frozen_string_literal: true

module BetterTogether
  # Concern that when included makes the model act as an identity
  module Permissible
    extend ActiveSupport::Concern

    included do
    end

    def self.available_roles
      ::BetterTogether::Role.for_class(self)
    end

    def available_roles
      ::BetterTogether::Role.for_class(self.class)
    end
  end
end
