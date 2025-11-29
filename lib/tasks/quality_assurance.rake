# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

namespace :better_together do
  namespace :qa do
    namespace :rich_text do
      namespace :links do
        desc 'Generates report of status of RichText links'
        task identify: :environment do
          result = BetterTogether::Metrics::RichTextLinkIdentifier.call
          puts "Valid links processed: #{result[:valid]}"
          puts "Invalid links processed: #{result[:invalid]}"
        end

        desc 'checks rich text links and returns their status code'
        task check: :environment do
          BetterTogether::Metrics::RichTextInternalLinkCheckerQueueJob.perform_later
          BetterTogether::Metrics::RichTextExternalLinkCheckerQueueJob.perform_later
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

# rubocop:enable Metrics/BlockLength
