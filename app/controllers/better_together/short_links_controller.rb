# frozen_string_literal: true

module BetterTogether
  class ShortLinksController < ResourceController # rubocop:todo Style/Documentation
    private

    def resource_class
      ShortLink
    end

    def resource_collection
      @resources ||= policy_scope(resource_class)
                     .where(platform: Current.platform)
                     .order(created_at: :desc)

      @short_links = @resources
    end
  end
end
