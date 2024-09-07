module BetterTogether
  module Content
    class PageBlock < ApplicationRecord
      include Positioned

      belongs_to :page, class_name: 'BetterTogether::Page'
      belongs_to :block, class_name: 'BetterTogether::Content::Block', dependent: :destroy

      accepts_nested_attributes_for :block, allow_destroy: true
    end
  end
end
