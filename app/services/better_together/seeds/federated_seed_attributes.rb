# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Maps CE content records to federated seed attribute hashes.
    # sync_depth controls payload richness:
    #   'metadata' — identifiers and dates only, no content bodies
    #   'standard' — flat attributes + ActionText HTML bodies (default)
    #   'full'     — standard + block layout (pages only, when implemented)
    #
    # Content bodies are read via SafeRichText, not the raw ActionText reader
    # -- see that module for why (a pathological rich text body can otherwise
    # blow the stack the moment it's read at all, regardless of sync_depth).
    module FederatedSeedAttributes
      module_function

      def post_attributes(record, sync_depth: 'standard')
        attrs = {
          title: record.title,
          identifier: record.identifier,
          privacy: record.privacy,
          published_at: record.published_at,
          updated_at: record.updated_at
        }
        attrs[:content] = SafeRichText.trix_html_for(record, :content) unless sync_depth == 'metadata'
        attrs
      end

      def page_attributes(record, sync_depth: 'standard')
        attrs = {
          title: record.title,
          identifier: record.identifier,
          privacy: record.privacy,
          published_at: record.published_at,
          updated_at: record.updated_at,
          layout: record.layout,
          template: record.template,
          meta_description: record.meta_description,
          keywords: record.keywords
        }
        # blocks key populated by FederatedPageBlockSerializer when sync_depth is 'full'
        attrs[:blocks] = [] if sync_depth == 'full'
        attrs
      end

      def event_attributes(record, sync_depth: 'standard')
        attrs = {
          name: record.name,
          identifier: record.identifier,
          privacy: record.privacy,
          updated_at: record.updated_at,
          starts_at: record.starts_at,
          ends_at: record.ends_at,
          duration_minutes: record.duration_minutes,
          registration_url: record.registration_url,
          timezone: record.timezone
        }
        attrs[:description] = SafeRichText.trix_html_for(record, :description) unless sync_depth == 'metadata'
        attrs
      end
    end
  end
end
