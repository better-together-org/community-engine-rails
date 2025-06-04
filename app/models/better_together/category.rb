# frozen_string_literal: true

module BetterTogether
  class Category < ApplicationRecord # rubocop:todo Style/Documentation
    include Attachments::Images
    include Identifier
    include Positioned
    include Protected
    include Translatable

    attachable_cover_image

    has_many :categorizations, dependent: :destroy
    has_many :pages, through: :categorizations, source: :categorizable, source_type: 'BetterTogether::Page'

    translates :name, type: :string
    translates :description, backend: :action_text

    slugged :name

    validates :name, presence: true
    validates :type, presence: true

    def self.permitted_attributes(id: false, destroy: false)
      super + [
        :type, :icon
      ]
    end

    def as_category
      becomes(self.class.base_class)
    end

    configure_attachment_cleanup
  end
end
