# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Service to scan ActionText::RichText records, extract links, and persist
    # both the link metadata (BetterTogether::Content::Link) and the join
    # records (BetterTogether::Metrics::RichTextLink).
    #
    # Usage:
    #   BetterTogether::Metrics::RichTextLinkIdentifier.call
    class RichTextLinkIdentifier # rubocop:disable Metrics/ClassLength
      def self.call(rich_texts: nil)
        new(rich_texts: rich_texts).call
      end

      def initialize(rich_texts: nil)
        @rich_texts = rich_texts
      end

      # rubocop:disable Metrics/MethodLength
      def call
        texts = rich_texts || ActionText::RichText.includes(:record).where.not(body: nil)
        valid_count = 0
        invalid_count = 0

        if texts.respond_to?(:find_each)
          texts.find_each do |rich_text|
            v, i = process_rich_text(rich_text)
            valid_count += v
            invalid_count += i
          end
        else
          Array(texts).each do |rich_text|
            v, i = process_rich_text(rich_text)
            valid_count += v
            invalid_count += i
          end
        end

        { valid: valid_count, invalid: invalid_count }
      end
      # rubocop:enable Metrics/MethodLength

      private

      attr_reader :rich_texts

      def extract_links(rich_text)
        # ActionText stores HTML; use the body helper to extract hrefs
        rich_text.body.links.uniq
      rescue StandardError
        []
      end

      # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      def process_rich_text(rich_text)
        valid_count = 0
        invalid_count = 0
        links = extract_links(rich_text)
        return [0, 0] if links.empty?

        links.each_with_index do |link, index|
          uri_obj = parse_uri(link)
          if uri_obj.nil?
            create_invalid(rich_text, index, link, 'undetermined')
            invalid_count += 1
            next
          end

          canonical_host = uri_obj.host
          if canonical_host.nil? && uri_obj.scheme.nil?
            if link.start_with?('/')
              canonical_host = rt_platform_host
            else
              create_invalid(rich_text, index, link, 'undetermined')
              invalid_count += 1
              next
            end
          end

          persist_link_and_rich_text_link(rich_text, link, index, canonical_host, uri_obj)
          valid_count += 1
        rescue URI::InvalidURIError
          create_invalid(rich_text, index, link, 'invalid_uri')
          invalid_count += 1
        end

        [valid_count, invalid_count]
      end
      # rubocop:enable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

      # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      def persist_link_and_rich_text_link(rich_text, link, index, canonical_host, uri_obj)
        bt_link = BetterTogether::Content::Link.find_or_initialize_by(url: link)
        bt_link.host ||= canonical_host
        bt_link.scheme ||= uri_obj.scheme
        bt_link.external = (canonical_host.present? && (rt_platform_host != canonical_host))
        # Ensure link_type is set to a sensible default before persisting to avoid
        # NOT NULL constraint violations (some callers create links directly).
        bt_link.link_type ||= 'website'
        bt_link.save! if bt_link.changed?

        # Persist the RichTextLink depending on the schema available.
        model = BetterTogether::Metrics::RichTextLink

        if model.column_names.include?('link_id')
          attrs = {
            link_id: bt_link.id,
            rich_text_id: rich_text.id,
            rich_text_record_id: rich_text.record_id,
            rich_text_record_type: rich_text.record_type,
            position: index,
            locale: rich_text.locale
          }

          # Build optional metadata hash only for columns that exist on the table
          optional_cols = %w[url link_type external valid_link host error_message]
          optional_cols.each do |c|
            next unless model.column_names.include?(c)

            attrs[c.to_sym] = case c
                              when 'url' then bt_link.url
                              when 'link_type' then bt_link.link_type || 'website'
                              when 'external' then bt_link.external || false
                              when 'valid_link' then bt_link.valid_link || false
                              when 'host' then bt_link.host
                              when 'error_message' then bt_link.error_message
                              end
          end

          begin
            model.create!(attrs)
          rescue ActiveRecord::RecordNotUnique
            # another process inserted concurrently; ignore
          end
        else
          # Fallback schema: metrics rich_text_links store URL and metadata inline.
          attrs = {
            rich_text_id: rich_text.id,
            url: link,
            link_type: bt_link.link_type || 'website',
            external: bt_link.external || false,
            valid_link: bt_link.valid_link || false,
            host: bt_link.host,
            error_message: bt_link.error_message
          }

          begin
            model.create!(attrs.merge(position: index, locale: rich_text.locale))
          rescue ActiveRecord::RecordNotUnique
            # ignore duplicate insertion races
          end
        end
      end
      # rubocop:enable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

      def parse_uri(link)
        URI.parse(link)
      end

      def create_invalid(rich_text, index, link, invalid_type)
        # Create the content link with a default link_type to satisfy DB constraints
        bt_link = BetterTogether::Content::Link.create!(url: link, valid_link: false, error_message: invalid_type,
                                                        link_type: 'website')

        BetterTogether::Metrics::RichTextLink.create!(
          rich_text_id: rich_text.id,
          rich_text_record_id: rich_text.record_id,
          rich_text_record_type: rich_text.record_type,
          position: index,
          locale: rich_text.locale,
          link: bt_link
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
