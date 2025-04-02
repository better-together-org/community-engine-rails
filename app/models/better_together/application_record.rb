# frozen_string_literal: true

module BetterTogether
  # Base model for the engine
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    include BetterTogetherId

    def self.extra_permitted_attributes
      []
    end

    def self.permitted_attributes(id: false, destroy: false, exclude_extra: false)
      attrs = exclude_extra ? [] : extra_permitted_attributes

      attrs << :id if id
      attrs << :_destroy if destroy

      attrs
    end

    def cache_key
      "#{I18n.locale}/#{super}"
    end

    def to_s
      return name if respond_to? :name
      return title if respond_to? :title
      return identifier if respond_to? :identifier
      return slug if respond_to? :slug

      super
    end
  end
end
