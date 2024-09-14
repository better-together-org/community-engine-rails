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

    has_one_attached :profile_image
    has_one_attached :cover_image

    # Virtual attributes to track removal
    attr_accessor :remove_profile_image, :remove_cover_image

    # Callbacks to remove images if necessary
    before_save :purge_profile_image, if: -> { remove_profile_image == '1' }
    before_save :purge_cover_image, if: -> { remove_cover_image == '1' }

    validates :name,
              presence: true
    validates :description,
              presence: true

    def to_s
      name
    end
  end
end
