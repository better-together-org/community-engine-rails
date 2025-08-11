# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for Joatu requests
    class RequestsController < ResourceController
      private

      def resource_class
        BetterTogether::Joatu::Request
      end

      def permitted_attributes
        super + %i[status name description]
      end
    end
  end
end
