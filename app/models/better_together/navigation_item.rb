# frozen_string_literal: true

module BetterTogether
  # An element in a navigation tree. Links to an internal or external page
  class NavigationItem < ApplicationRecord
    include Identifier
    include Positioned
    include Protected

    belongs_to :navigation_area
    belongs_to :linkable, polymorphic: true, optional: true, autosave: true

    # Association with parent item
    belongs_to :parent,
               class_name: 'NavigationItem',
               optional: true

    # Association with child items
    has_many :children,
             lambda {
               positioned
             },
             class_name: 'NavigationItem',
             foreign_key: 'parent_id',
             dependent: :destroy

    # Define valid linkable classes
    LINKABLE_CLASSES = [
      '::BetterTogether::Page',
      'BetterTogether::Page'
    ].freeze

    slugged :title

    translates :title

    validates :title, presence: true, length: { maximum: 255 }
    validates :url,
              format: { with: %r{\A(http|https)://.+\z|\A#\z|^/*[\w/-]+}, allow_blank: true,
                        message: 'must be a valid URL, "#", or an absolute path' }
    validates :visible, inclusion: { in: [true, false] }
    validates :item_type, inclusion: { in: %w[link dropdown separator], allow_blank: true }
    validates :linkable_type, inclusion: { in: LINKABLE_CLASSES, allow_nil: true }

    # Scope to return top-level navigation items
    scope :top_level, -> { where(parent_id: nil) }

    scope :visible, -> { where(visible: true) }

    def build_children(pages, navigation_area) # rubocop:todo Metrics/MethodLength
      pages.each_with_index do |page, index|
        children.build(
          navigation_area:,
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

    def child?
      parent_id.present?
    end

    def dropdown?
      item_type == 'dropdown'
    end

    def item_type
      return read_attribute(:item_type) if persisted? || read_attribute(:item_type).present?

      'link'
    end

    def set_position
      return read_attribute(:position) if persisted? || read_attribute(:position).present?

      max_position = navigation_area.navigation_items.maximum(:position)
      max_position ? max_position + 1 : 0
    end

    def title
      return super unless linkable.present? && linkable.respond_to?(:title)

      linkable.title
    end

    def title= arg
      return super(arg) unless linkable.present? && linkable.respond_to?(:title=)

      linkable.title = arg
    end

    def url
      if linkable.present?
        linkable.url
      else
        _url = read_attribute(:url) # or super # rubocop:todo Lint/UnderscorePrefixedVariableName
        return _url if _url.present?

        '#'
      end
    end

    # Other validations and logic...
  end
end
