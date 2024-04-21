# frozen_string_literal: true

module BetterTogether
  # Used to determine the user's access to features and data
  class Role < ApplicationRecord
    RESOURCE_CLASSES = [
      '::BetterTogether::Platform'
    ].freeze
    
    include Identifier
    include Positioned
    include Protected

    slugged :identifier, dependent: :delete_all

    translates :name
    translates :description, type: :text

    validates :name,
              presence: true
    validates :resource_class, inclusion: { in: RESOURCE_CLASSES }

    def to_s
      name
    end
  end
end
