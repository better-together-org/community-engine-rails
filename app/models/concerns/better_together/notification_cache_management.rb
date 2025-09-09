# frozen_string_literal: true

module BetterTogether
  # Concern for managing notification fragment caches
  module NotificationCacheManagement
    extend ActiveSupport::Concern

    included do
      # Automatically expire fragment caches when notification changes
      after_update :expire_notification_caches, if: :should_expire_caches?
      after_destroy :expire_notification_caches
    end

    private

    def expire_notification_caches
      # Use the helper methods to expire relevant fragments
      ApplicationController.helpers.expire_notification_fragments(self) if respond_to_cache_methods?
    end

    def should_expire_caches?
      # Expire caches on status changes (read/unread) or content changes
      saved_change_to_read_at? || saved_change_to_created_at? || saved_change_to_updated_at?
    end

    def respond_to_cache_methods?
      ApplicationController.helpers.respond_to?(:expire_notification_fragments)
    rescue StandardError
      false
    end
  end
end
