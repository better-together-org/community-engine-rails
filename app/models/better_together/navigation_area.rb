# app/models/better_together/navigation_area.rb

module BetterTogether
  class NavigationArea < ApplicationRecord
    include FriendlySlug
    include Protected

    slugged :name

    belongs_to :navigable, polymorphic: true
    has_many :navigation_items, dependent: :destroy

    validates :name, presence: true, uniqueness: true
    validates :visible, inclusion: { in: [true, false] }
    validates :style, length: { maximum: 255 }, allow_blank: true

    # Additional model logic...
    scope :visible, -> { where(visible: true) }
  end
end
