# frozen_string_literal: true

module BetterTogether
  module Content
    # Represents a persisted link discovered in rich content. Stores metadata
    # about the link (host, scheme, validity) and associates to RichText
    # metrics records.
    class Link < ApplicationRecord
      has_many :rich_text_links, class_name: 'BetterTogether::Metrics::RichTextLink', inverse_of: :link
      has_many :rich_texts, through: :rich_text_links
      has_many :rich_text_records, through: :rich_text_links
    end
  end
end
