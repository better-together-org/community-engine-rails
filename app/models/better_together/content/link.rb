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

      # Provide safe defaults for tests and ad-hoc creation so callers don't
      # need to remember non-nullable columns. These mirror reasonable
      # expectations for persisted links.
      after_initialize do |record|
        record.link_type = 'website' if record.link_type.blank?
        record.valid_link = false if record.valid_link.nil?
      end
    end
  end
end
