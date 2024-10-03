# frozen_string_literal: true

# app/models/better_together/navigation_area.rb

module BetterTogether
  # A named list of ordered multi-level navigation items
  class NavigationArea < ApplicationRecord
    include Identifier
    include Protected
    include Visible

    slugged :name
    translates :name, type: :string

    belongs_to :navigable, polymorphic: true, optional: true
    has_many :navigation_items, dependent: :destroy

    validates :name, presence: true, uniqueness: true
    validates :style, length: { maximum: 255 }, allow_blank: true

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

    def top_level_nav_items_includes_children
      self&.navigation_items&.includes(:string_translations, :linkable, children:
                                %i[string_translations linkable])&.visible&.top_level&.positioned # rubocop:enable Metrics/CollectionLiteralLength
    end

    def to_s
      name
    end
  end
end
