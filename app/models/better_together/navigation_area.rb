# frozen_string_literal: true

# app/models/better_together/navigation_area.rb

module BetterTogether
  # A named list of ordered multi-level navigation items
  class NavigationArea < ApplicationRecord
    include Identifier
    include Protected

    slugged :name

    belongs_to :navigable, polymorphic: true, optional: true
    has_many :navigation_items, dependent: :destroy

    validates :name, presence: true, uniqueness: true
    validates :visible, inclusion: { in: [true, false] }
    validates :style, length: { maximum: 255 }, allow_blank: true

    # Additional model logic...
    scope :visible, -> { where(visible: true) }

    def build_page_navigation_items(pages) # rubocop:todo Metrics/MethodLength
      pages.each_with_index do |page, index|
        navigation_items.build(
          title: page.title,
          slug: page.slug,
          position: index,
          visible: true,
          protected: true,
          item_type: 'link',
          url: '',
          linkable: page
        )
      end
    end
  end
end
