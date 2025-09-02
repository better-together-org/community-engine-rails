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

        if texts.respond_to?(:find_each)
          texts.find_each do |rt|
            v, i = process_rich_text(rt)
            valid_count += v
            invalid_count += i
          end
        else
          Array(texts).each do |rt|
            v, i = process_rich_text(rt)
            valid_count += v
            invalid_count += i
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

      def process_rich_text(rt)
        valid_count = 0
        invalid_count = 0
        links = extract_links(rt)
        return [0, 0] if links.empty?

        links.each_with_index do |link, index|
          begin
            uri = parse_uri(link)
            if uri.nil?
              create_invalid(rt, index, link, 'undetermined')
              invalid_count += 1
              next
            end

            canonical_host = uri.host
            if canonical_host.nil? && uri.scheme.nil?
              if link.start_with?('/')
                canonical_host = rt_platform_host
              else
                create_invalid(rt, index, link, 'undetermined')
                invalid_count += 1
                next
              end
            end

            bt_link = BetterTogether::Content::Link.find_or_initialize_by(url: link)
            bt_link.host ||= canonical_host
            bt_link.scheme ||= uri.scheme
            bt_link.external = (canonical_host.present? && (rt_platform_host != canonical_host))
            bt_link.save! if bt_link.changed?

            # Persist the RichTextLink depending on the schema available.
            if BetterTogether::Metrics::RichTextLink.column_names.include?('link_id')
              attrs = {
                link_id: bt_link.id,
                rich_text_id: rt.id,
                rich_text_record_id: rt.record_id,
                rich_text_record_type: rt.record_type,
                position: index,
                locale: rt.locale
              }

              BetterTogether::Metrics::RichTextLink.find_or_create_by!(attrs)
            else
              # Fallback schema: metrics rich_text_links store URL and metadata inline
              # Some legacy schemas use column names (for example `valid`) that clash
              # with Active Record method names. To avoid DangerousAttributeError we
              # perform a raw INSERT unless a record already exists for this
              # (rich_text_id, url) tuple.
              model = BetterTogether::Metrics::RichTextLink
              unless model.where(rich_text_id: rt.id, url: link).exists?
                conn = model.connection
                table = model.table_name
                now = Time.current
                cols = %w[rich_text_id url link_type external valid host error_message created_at updated_at]
                vals = [rt.id, link, bt_link.link_type || 'website', bt_link.external || false,
                        bt_link.valid_link || false, bt_link.host, bt_link.error_message, now, now]
                sql = "INSERT INTO #{table} (#{cols.join(',')}) VALUES (#{vals.map { |v| conn.quote(v) }.join(',')})"
                conn.execute(sql)
              end
            end

            valid_count += 1
          rescue URI::InvalidURIError
            create_invalid(rt, index, link, 'invalid_uri')
            invalid_count += 1
          end
        end

        [valid_count, invalid_count]
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
