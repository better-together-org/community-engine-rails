module BetterTogether
  class NavigationItem < ApplicationRecord
    include FriendlySlug

    slugged :title

    belongs_to :navigation_area
    belongs_to :linkable, polymorphic: true, optional: true

    # Define valid linkable classes
    LINKABLE_CLASSES = ['::BetterTogether::Page'].freeze

    validates :title, presence: true, length: { maximum: 255 }
    validates :url, format: { with: URI::regexp(%w[http https]), allow_blank: true }
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :visible, inclusion: { in: [true, false] }
    validates :item_type, inclusion: { in: %w[link dropdown separator], allow_blank: true }
    validates :linkable_type, inclusion: { in: LINKABLE_CLASSES, allow_nil: true }

    scope :visible, -> { where(visible: true) }

    def position
      return read_attribute(:position) if persisted? || read_attribute(:position).present?

      max_position = self.navigation_area.navigation_items.maximum(:position)
      max_position ? max_position + 1 : 0
    end

    def item_type
      return read_attribute(:item_type) if persisted? || read_attribute(:item_type).present?
      'link'
    end

    def url
      if linkable.present?
        linkable.url
      else
        read_attribute(:url) # or super
      end
    end

    # Other validations and logic...
  end
end
