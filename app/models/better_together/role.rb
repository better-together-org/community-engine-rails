# frozen_string_literal: true

module BetterTogether
  # Used to determine the user's access to features and data
  class Role < ApplicationRecord
    TARGET_CLASSES = [
      '::BetterTogether::Platform'
    ].freeze
    
    include FriendlySlug
    include Mobility
    include Positioned
    include Protected

    slugged :identifier

    translates :name
    translates :description, type: :text

    validates :identifier, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 100 }
    validates :name,
              presence: true
    validates :target_class, inclusion: { in: TARGET_CLASSES }

    def to_s
      name
    end
  end
end
