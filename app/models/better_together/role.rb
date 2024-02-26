# frozen_string_literal: true

module BetterTogether
  # Used to determine the user's access to features and data
  class Role < ApplicationRecord
    TARGET_CLASSES = [
      '::BetterTogether::Platform'
    ].freeze
    
    include Identifier
    include Positioned
    include Protected

    translates :name
    translates :description, type: :text

    validates :name,
              presence: true
    validates :target_class, inclusion: { in: TARGET_CLASSES }

    def to_s
      name
    end
  end
end
