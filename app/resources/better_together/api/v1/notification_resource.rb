# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes Noticed::Notification for JSONAPI
      # Read-only resource for user notifications
      class NotificationResource < ::BetterTogether::Api::ApplicationResource
        model_name '::Noticed::Notification'

        # Standard attributes
        attributes :read_at

        # Virtual attributes
        attribute :is_read
        attribute :notification_type
        attribute :params

        # Filters
        filter :read, apply: lambda { |records, value, _options|
          if ActiveModel::Type::Boolean.new.cast(value.first)
            records.where.not(read_at: nil)
          else
            records.where(read_at: nil)
          end
        }

        # Custom attribute methods
        def is_read # rubocop:disable Naming/PredicatePrefix, Naming/PredicateMethod
          @model.read_at.present?
        end

        def notification_type
          @model.type.to_s.demodulize.underscore
        end

        def params
          # Return safe params, excluding any sensitive data
          safe_params = @model.params&.dup || {}
          safe_params.except('_aj_serialized', '_aj_globalid')
        end

        # Scope notifications to the current user's person
        # Uses manual scope instead of Pundit policy_scope since Noticed::Notification
        # doesn't have a Pundit policy — notifications are scoped by recipient only
        def self.records(options = {})
          context = options[:context]
          context[:policy_used]&.call
          person = context&.dig(:current_person)

          if person
            Noticed::Notification
              .where(recipient_type: 'BetterTogether::Person', recipient_id: person.id)
              .order(created_at: :desc)
          else
            Noticed::Notification.none
          end
        end

        # Read-only resource (mark_read handled via custom controller action)
        def self.creatable_fields(_context)
          []
        end

        def self.updatable_fields(_context)
          %i[read_at] # Allow marking as read
        end
      end
    end
  end
end
