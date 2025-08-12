# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for Joatu agreements
    class AgreementsController < ResourceController
      private

      def resource_class
        BetterTogether::Joatu::Agreement
      end

      def permitted_attributes
        super + %i[offer_id request_id terms value status]
      end
    end
  end
end
