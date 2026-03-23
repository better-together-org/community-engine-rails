# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Maps CE content records to federated seed attribute hashes.
    module FederatedSeedAttributes
      module_function

      def post_attributes(record)
        {
          title: record.title,
          content: record.content&.body&.to_plain_text.to_s,
          identifier: record.identifier,
          privacy: record.privacy,
          published_at: record.published_at,
          updated_at: record.updated_at
        }
      end

      def page_attributes(record)
        {
          title: record.title,
          content: record.content&.body&.to_plain_text.to_s,
          identifier: record.identifier,
          privacy: record.privacy,
          published_at: record.published_at,
          updated_at: record.updated_at,
          layout: record.layout,
          template: record.template,
          meta_description: record.meta_description,
          keywords: record.keywords
        }
      end

      def event_attributes(record)
        {
          name: record.name,
          description: record.description&.body&.to_plain_text.to_s,
          identifier: record.identifier,
          privacy: record.privacy,
          updated_at: record.updated_at,
          starts_at: record.starts_at,
          ends_at: record.ends_at,
          duration_minutes: record.duration_minutes,
          registration_url: record.registration_url,
          timezone: record.timezone
        }
      end
    end
  end
end
