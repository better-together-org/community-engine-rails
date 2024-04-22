# frozen_string_literal: true

module BetterTogether
  # A gathering
  class Community < ApplicationRecord
    include Host
    include Identifier
    include Joinable
    include Protected
    include Privacy
    include Permissible

    belongs_to :creator,
               class_name: '::BetterTogether::Person',
               optional: true

    joinable joinable_type: 'community',
             member_type: 'person'
    
    slugged :name

    translates :name
    translates :description, type: :text

    validates :name,
              presence: true
    validates :description,
              presence: true

    def to_s
      name
    end
  end
end
