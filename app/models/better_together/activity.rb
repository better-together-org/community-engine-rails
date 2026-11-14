# frozen_string_literal: true

module BetterTogether
  # Platform-scoped wrapper around PublicActivity::Activity.
  # Ensures every audit trail entry is tagged to the platform where the
  # action occurred, enabling per-platform activity feeds and admin views.
  #
  # PublicActivity is configured to use this class via
  # config/initializers/public_activity.rb:
  #   PublicActivity.configure { |config| config.activity_model = 'BetterTogether::Activity' }
  class Activity < PublicActivity::Activity
    include PlatformScoped

    before_create :ensure_platform_from_trackable

    private

    def ensure_platform_from_trackable
      return if platform_id.present?

      # Prefer the trackable's own platform (e.g. a Post created on Platform A).
      if trackable.respond_to?(:platform) && trackable.platform.present?
        self.platform = trackable.platform
        return
      end

      # Fall back to the current request platform or the host platform.
      self.platform = Current.platform ||
                      BetterTogether::Platform.find_by(host: true) ||
                      BetterTogether::Platform.first
    end
  end
end
