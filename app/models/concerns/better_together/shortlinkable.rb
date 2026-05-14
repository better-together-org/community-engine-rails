# frozen_string_literal: true

module BetterTogether
  module Shortlinkable # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      has_one :short_link, as: :linkable,
                           class_name: 'BetterTogether::ShortLink',
                           dependent: :destroy
    end

    def ensure_short_link!
      return short_link if short_link&.active_and_unexpired?

      create_short_link!(
        target_url: short_link_target_url,
        platform: Current.platform,
        creator: Current.person
      )
    end

    def short_link_target_url
      return url if respond_to?(:url, true)

      raise NotImplementedError, "#{self.class.name} must define short_link_target_url or url"
    end
  end
end
