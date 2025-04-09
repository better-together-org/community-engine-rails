# frozen_string_literal: true

module BetterTogether
  module HumanAttributeNameHelper
    # Dispatches the human attribute name for a given model instance and attribute
    # @param model [ActiveRecord::Base] The model instance
    # @param attribute [Symbol, String] The attribute name
    # @return [String] The human-readable attribute name
    def human_attribute_name_for(model, attribute)
      model.class.human_attribute_name(attribute)
    end
  end
end
