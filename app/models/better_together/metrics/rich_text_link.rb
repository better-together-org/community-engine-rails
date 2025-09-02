# frozen_string_literal: true

module BetterTogether
  module Metrics
    class RichTextLink < ApplicationRecord
      belongs_to :link, class_name: 'BetterTogether::Content::Link'
      belongs_to :rich_text, class_name: 'ActionText::RichText'
      belongs_to :rich_text_record, polymorphic: true

      accepts_nested_attributes_for :link, reject_if: ->(attributes) { attributes['url'].blank? }, allow_destroy: false
    end
  end
end
