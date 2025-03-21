# frozen_string_literal: true

module BetterTogether
  # Base model for the engine
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    include BetterTogetherId
    include Seedable

    def self.extra_permitted_attributes
      []
    end

    def cache_key
      "#{I18n.locale}/#{super}"
    end
  end
end
