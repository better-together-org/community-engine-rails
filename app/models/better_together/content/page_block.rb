# frozen_string_literal: true

module BetterTogether
  module Content
    # Joins page and block ordered by position
    class PageBlock < ApplicationRecord
      include Positioned

      belongs_to :page, class_name: 'BetterTogether::Page', touch: true
      belongs_to :block, class_name: 'BetterTogether::Content::Block', dependent: :destroy

      accepts_nested_attributes_for :block, allow_destroy: true
    end
  end
end
