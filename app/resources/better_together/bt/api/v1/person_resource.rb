# frozen_string_literal: true

module BetterTogether
  module Bt
    module Api
      module V1
        # Serializes the Person class
        class PersonResource < ::BetterTogether::ApiResource
          model_name '::BetterTogether::Person'

          attributes :name, :description, :slug
        end
      end
    end
  end
end
