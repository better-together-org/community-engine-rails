# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Service to scan ActionText::RichText records, extract links, and persist
    # both the link metadata (BetterTogether::Content::Link) and the join
    # records (BetterTogether::Metrics::RichTextLink).
    #
    # Usage:
    #   BetterTogether::Metrics::RichTextLinkIdentifier.call
    class RichTextLinkIdentifier
      def self.call(rich_texts: nil)
        new(rich_texts: rich_texts).call
      end

      def initialize(rich_texts: nil)
        @rich_texts = rich_texts
      end

      def call
        texts = rich_texts || ActionText::RichText.includes(:record).where.not(body: nil)
        valid_count = 0
        invalid_count = 0

        texts.find_each do |rt|
          links = extract_links(rt)
          next if links.empty?

          links.each_with_index do |link, index|
            uri = parse_uri(link)
            if uri.nil? || (uri.host.nil? && uri.scheme.nil?)
              create_invalid(rt, index, link, 'undetermined')
              invalid_count += 1
              next
            end

            # Create or find the canonical Link record
            bt_link = BetterTogether::Content::Link.find_or_initialize_by(url: link)
            bt_link.host ||= uri.host
            bt_link.scheme ||= uri.scheme
            bt_link.external = (uri.host.present? && (rt_platform_host != uri.host))
            bt_link.save! if bt_link.changed?

            # Create or update the rich text link join record
            attrs = {
              link_id: bt_link.id,
              rich_text_id: rt.id,
              rich_text_record_id: rt.record_id,
              rich_text_record_type: rt.record_type,
              position: index,
              locale: rt.locale
            }

            BetterTogether::Metrics::RichTextLink.find_or_create_by!(attrs)
            valid_count += 1
          rescue URI::InvalidURIError
            create_invalid(rt, index, link, 'invalid_uri')
            invalid_count += 1
          end
        end

        { valid: valid_count, invalid: invalid_count }
      end

      private

      attr_reader :rich_texts

      def extract_links(rt)
        # ActionText stores HTML; use the body helper to extract hrefs
        rt.body.links.uniq
      rescue StandardError
        []
      end

      def parse_uri(link)
        URI.parse(link)
      end

      def create_invalid(rt, index, link, invalid_type)
        BetterTogether::Metrics::RichTextLink.create!(
          rich_text_id: rt.id,
          rich_text_record_id: rt.record_id,
          rich_text_record_type: rt.record_type,
          position: index,
          locale: rt.locale,
          link: BetterTogether::Content::Link.create!(url: link, valid_link: false, error_message: invalid_type)
        )
      end

      def rt_platform_host
        @rt_platform_host ||= begin
          host_platform = BetterTogether::Platform.host.first
          URI(host_platform.url).host
        rescue StandardError
          nil
        end
      end
    end
  end
end
