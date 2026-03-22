# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for notifications
      # Notifications are scoped to the current user's person
      class NotificationsController < BetterTogether::Api::ApplicationController
        # GET /api/v1/notifications
        # Returns notifications for the authenticated user
        # Supports filter[read]=true/false
        def index
          super
        end

        # GET /api/v1/notifications/:id
        # Returns a specific notification
        def show
          super
        end

        # PATCH/PUT /api/v1/notifications/:id
        # Allows marking notifications as read via read_at attribute
        def update
          super
        end

        # POST /api/v1/notifications/mark_all_read
        # Custom action to mark all unread notifications as read
        # We manually set @policy_used because this bypasses JSONAPI resources
        def mark_all_read
          person = current_user&.person
          return head(:unauthorized) unless person

          @policy_used = true # Manual authorization: scoped to authenticated user's person

          Noticed::Notification
            .where(recipient_type: 'BetterTogether::Person', recipient_id: person.id, read_at: nil)
            .update_all(read_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

          head :no_content
        end
      end
    end
  end
end
