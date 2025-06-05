# frozen_string_literal: true

module BetterTogether
  class CategoriesController < FriendlyResourceController # rubocop:todo Style/Documentation
    before_action only: %i[new edit index], if: -> { Rails.env.development? } do
      # Make sure that all subclasses are loaded in dev to generate type selector
      Rails.application.eager_load!
    end

    # def index
    #   raise 'test'
    # end

    protected

    def resource_class
      ::BetterTogether::Category
    end

    def resource_collection
      resource_class.with_translations
    end
  end
end
