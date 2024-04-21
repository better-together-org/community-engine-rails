# frozen_string_literal: true

module BetterTogether
  # Used to determine the user's access to features and data
  class Role < ApplicationRecord
    RESOURCE_CLASSES = [
      'BetterTogether::Community',
      'BetterTogether::Platform'
    ].freeze
    
    include Identifier
    include Positioned
    include Protected

    slugged :identifier, dependent: :delete_all

    translates :name
    translates :description, type: :text

    validates :name,
              presence: true
    validates :resource_type, inclusion: { in: RESOURCE_CLASSES }

    scope :positioned, -> { order(:resource_type, :position) }

    def position_scope
      :resource_type
    end

    def to_s
      name
    end
  end
end
