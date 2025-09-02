# frozen_string_literal: true

namespace :better_together do
  namespace :qa do
    namespace :rich_text do
      namespace :links do
        desc 'Generates report of status of RichText links'
        task identify: :environment do
          require 'uri'

          host_platform = BetterTogether::Platform.host.first
          platform_uri = URI(host_platform.url)

          rich_texts = ActionText::RichText.includes(:record).where.not(body: nil)
          puts 'rich text count:', rich_texts.size

          valid_rich_text_links = []
          invalid_rich_text_links = []

          rich_texts.each do |rt|
            links = rt.body.links.uniq # Deduplicate links within the same rich text
            next unless links.any?

            links.each_with_index do |link, index|
              uri = URI.parse(link)

              internal_link = uri.host == platform_uri.host
              link_type = determine_link_type(uri, internal_link)

              if uri.host.nil? && uri.scheme.nil?
                invalid_type = if uri.path
                                 'path'
                               elsif link.include?('mailto')
                                 'email'
                               elsif link.include?('tel')
                                 'phone'
                               else
                                 'undetermined'
                               end

                invalid_rich_text_links << {
                  rich_text_id: rt.id,
                  rich_text_record_id: rt.record_id,
                  rich_text_record_type: rt.record_type,
                  locale: rt.locale,
                  position: index, # Track the first position for clarity

                  link_attributes: {
                    url: link,
                    link_type: "invalid:#{invalid_type}",
                    valid_link: false,
                    error_message: 'No host or scheme. Needs review.'
                  }
                }

                next
              end

              valid_rich_text_links << {
                rich_text_id: rt.id,
                rich_text_record_id: rt.record_id,
                rich_text_record_type: rt.record_type,
                locale: rt.locale,
                position: index, # Track the first position for clarity

                link_attributes: {
                  url: link,
                  host: uri.host,
                  link_type: link_type,
                  valid_link: true,
                  external: !internal_link
                }
              }
            rescue URI::InvalidURIError => e
              invalid_type = if link.include?('mailto')
                               'email'
                             elsif link.include?('tel')
                               'phone'
                             else
                               'undetermined'
                             end

              invalid_rich_text_links << {
                rich_text_id: rt.id,
                rich_text_record_id: rt.record_id,
                rich_text_record_type: rt.record_type,
                locale: rt.locale,
                position: index, # Track the first position for clarity

                link_attributes: {
                  url: link,
                  link_type: "invalid:#{invalid_type}",
                  valid_link: false,
                  error_message: e.message
                }
              }
            end
          end

          # Upsert valid and invalid links
          if valid_rich_text_links.any?
            BetterTogether::Metrics::RichTextLink.upsert_all(valid_rich_text_links,
                                                             unique_by: %i[rich_text_id position
                                                                           locale])
          end
          if invalid_rich_text_links.any?
            BetterTogether::Metrics::RichTextLink.upsert_all(invalid_rich_text_links,
                                                             unique_by: %i[rich_text_id position
                                                                           locale])
          end

          puts "Valid links processed: #{valid_rich_text_links.size}"
          puts "Invalid links processed: #{invalid_rich_text_links.size}"
        end

        desc 'checks rich text links and returns their status code'
        task check: :environment do
          BetterTogether::Metrics::RichTextInternalLinkCheckerQueueJob.new
          BetterTogether::Metrics::RichTextExternalLinkCheckerQueueJob.new
          byebug
        end

        def determine_link_type(uri, internal_link)
          if uri.scheme == 'mailto'
            'email'
          elsif uri.scheme == 'tel'
            'phone'
          elsif internal_link
            'internal'
          else
            'external'
          end
        end
      end
    end
  end
end
