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

      class << self
        # Pundit::Resource prints a show?-related warning every time records() is
        # called for policies that intentionally expose both controller show? and
        # resource scope semantics. Preserve the scope-based authorization path
        # without flooding CI logs.
        def records(options = {})
          context = options[:context]
          context[:policy_used]&.call
          Pundit.policy_scope!(context[:current_user], _model_class)
        end
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

        Rails.application.routes.url_helpers.rails_storage_proxy_url(attachment)
      rescue ActiveStorage::FileNotFoundError
        nil
      end

      # Helper method for polymorphic attachment URLs with variant support
      # Returns optimized variant URL based on image type using the storage proxy
      def optimized_attachment_url(attachment_name, variant: :optimized_jpeg)
        attachment = @model.send(attachment_name)
        return nil unless attachment.attached?

        if attachment.content_type == 'image/svg+xml'
          Rails.application.routes.url_helpers.rails_storage_proxy_url(attachment)
        else
          Rails.application.routes.url_helpers.rails_storage_proxy_url(attachment.variant(variant))
        end
      rescue ActiveStorage::FileNotFoundError
        nil
      end
    end
  end
end
