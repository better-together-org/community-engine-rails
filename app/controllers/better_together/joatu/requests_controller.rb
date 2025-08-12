# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Allows people to request something
    class RequestsController < ResourceController
      protected

      def resource_class
        ::BetterTogether::Joatu::Request
      end

      def resource_params
        super.tap do |attrs|
          attrs[:target_type] = 'BetterTogether::PlatformInvitation'
          attrs[:creator] = BetterTogether::Person.create!(name: attrs[:name])
        end
      end

      def permitted_attributes
        super + %i[status name description]
      end
    end
  end
end
