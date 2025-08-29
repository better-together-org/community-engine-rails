# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Platform-manager CRUD for Joatu categories
    class CategoriesController < ::BetterTogether::CategoriesController
      protected

      def resource_class
        ::BetterTogether::Joatu::Category
      end

      def resource_collection
        policy_scope(resource_class).with_translations
      end
    end
  end
end
