# frozen_string_literal: true

module BetterTogether
  # helper methdos for categories
  module CategoriesHelper
    def category_class(type)
      Rails.application.eager_load! unless Rails.env.production? # Ensure all models are loaded
      valid_types = [BetterTogether::Category, *BetterTogether::Category.descendants]
      valid_types.find { |klass| klass.to_s == type }
    end
  end
end
