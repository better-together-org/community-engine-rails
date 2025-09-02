# frozen_string_literal: true

module BetterTogether
  module Content
    class Link < ApplicationRecord
      has_many :rich_text_links, class_name: 'BetterTogether::Metrics::RichTextLink', inverse_of: :link
      has_many :rich_texts, through: :rich_text_links
      has_many :rich_text_records, through: :rich_text_links
    end
  end
end
