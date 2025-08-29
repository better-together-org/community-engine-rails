# frozen_string_literal: true

require 'better_together/api_resource'

module BetterTogether
  module Bt
    module Api
      module V1
        # Serializes the Role class
        class RoleResource < ::BetterTogether::ApiResource
          model_name '::BetterTogether::Role'

          attributes :name, :description, :sort_order, :reserved
        end
      end
    end
  end
end
