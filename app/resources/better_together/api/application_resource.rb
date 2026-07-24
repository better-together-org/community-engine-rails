# frozen_string_literal: true

require_dependency 'jsonapi/resource'

module BetterTogether
  # Base JSONAPI serializer that sets common attributes and helper methods
  module Api
    # Base resource class for Better Together JSONAPI serialization.
    # Provides helpers for Active Storage attachments, Mobility translations,
    # and standardized resource configuration.
    class ApplicationResource < ::JSONAPI::Resource
      abstract
      include Pundit::Resource

      key_type :string

      attributes :created_at, :updated_at

      # Override pundit-resources' default `records` to skip its `warn_if_show_defined`
      # check. That check assumes policies never define `show?` because pundit-resources
      # relies solely on the policy's Scope class for filtering — but our policies
      # legitimately define `show?` too, since it's used directly by the regular
      # (non-JSONAPI) HTML controllers via Pundit's `authorize resource_instance`.
      # Without this override, every API resource whose policy defines `show?` would
      # print a "WARN: pundit-resources does not use the show? action." line to
      # stdout on every `.records` call — pure noise in test/CI output and logs.
      # Behavior is otherwise identical to the gem's implementation.
      def self.records(options = {})
        context = options[:context]
        context[:policy_used]&.call
        Pundit.policy_scope!(context[:current_user], _model_class)
      end

      # Helper method for defining translatable attributes
      # Usage: translatable_attribute :name
      def self.translatable_attribute(attr_name)
        attribute attr_name do
          @model.send(attr_name)
        end
      end

      # Helper method for attachment URLs
      # Returns the URL for an Active Storage attachment using the storage proxy
      def attachment_url(attachment_name)
        attachment = @model.send(attachment_name)
        return nil unless attachment.attached?
        return nil unless BetterTogether::ContentSecurity::BlobAccessPolicy.public_proxy_allowed?(attachment.blob)

        attachment_proxy_url(attachment)
      rescue ActiveStorage::FileNotFoundError
        nil
      end

      # Helper method for polymorphic attachment URLs with variant support
      # Returns optimized variant URL based on image type using the storage proxy
      def optimized_attachment_url(attachment_name, variant: :optimized_jpeg)
        attachment = @model.send(attachment_name)
        return nil unless attachment.attached?
        return nil unless BetterTogether::ContentSecurity::BlobAccessPolicy.public_proxy_allowed?(attachment.blob)

        if attachment.content_type == 'image/svg+xml'
          attachment_proxy_url(attachment)
        else
          variant_proxy_url(attachment.variant(variant))
        end
      rescue ActiveStorage::FileNotFoundError
        nil
      end

      private

      def attachment_proxy_url(attachment)
        BetterTogether::MediaUrlBuilder.proxy_url_for(
          attachment,
          url_options: route_url_options
        )
      end

      def variant_proxy_url(variant)
        BetterTogether::MediaUrlBuilder.proxy_url_for(
          variant,
          url_options: route_url_options
        )
      end

      def route_url_options
        @route_url_options ||= Rails.application.routes.default_url_options.symbolize_keys
      end
    end
  end
end
