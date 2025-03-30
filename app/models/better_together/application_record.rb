# frozen_string_literal: true

module BetterTogether
  # Base model for the engine
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    include BetterTogetherId

    def self.extra_permitted_attributes
      []
    end

    def self.permitted_attributes(id: false, destroy: false)
      attrs = extra_permitted_attributes

      attrs << :id if id
      attrs << :_destroy if destroy

      attrs
    end

    def cache_key
      "#{I18n.locale}/#{super}"
    end
  end
end
