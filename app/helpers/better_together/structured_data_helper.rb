# frozen_string_literal: true

module BetterTogether
  # Helper methods for rendering JSON-LD structured data for schema.org
  module StructuredDataHelper
    def structured_data_tag(data)
      return if data.blank?

      tag.script(type: 'application/ld+json') do
        raw(Array.wrap(data).to_json)
      end
    end

    def platform_structured_data(platform)
      {
        '@context': 'https://schema.org',
        '@type': 'WebSite',
        name: platform.name,
        url: platform.url
      }
    end

    def community_structured_data(community)
      data = {
        '@context': 'https://schema.org',
        '@type': 'Organization',
        name: community.name,
        url: community_url(community)
      }
      data[:description] = community.description.to_plain_text if community.respond_to?(:description) && community.description.present?
      if community.logo.attached?
        attachment = community.respond_to?(:optimized_logo) ? community.optimized_logo : community.logo
        data[:logo] = rails_storage_proxy_url(attachment)
      end
      data
    end

    def event_structured_data(event)
      data = {
        '@context': 'https://schema.org',
        '@type': 'Event',
        name: event.name,
        startDate: event.starts_at&.iso8601,
        endDate: event.ends_at&.iso8601,
        url: event_url(event)
      }
      data[:description] = event.description.to_plain_text if event.respond_to?(:description) && event.description.present?
      data[:location] = event.location.to_s if event.respond_to?(:location) && event.location.present?
      data.compact
    end
  end
end
