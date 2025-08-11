# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Request
    class RequestsController < ResourceController
      protected

      def resource_class
        ::BetterTogether::Joatu::Request
      end

      def resource_params
        super.tap do |attrs|
          attrs[:creator_id] = helpers.current_person&.id if action_name == 'create'
        end
      end
    end
  end
end
