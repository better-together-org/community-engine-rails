# frozen_string_literal: true

module BetterTogether
  # Helpers for Badges
  module BadgesHelper
    def privacy_badge(entity, rounded: true, style: 'primary')
      return unless entity.respond_to? :privacy

      badge_label = entity.privacy.humanize.capitalize
      rounded_class = rounded ? 'rounded-pill' : ''
      style_class = "text-bg-#{style}"

      content_tag :span, badge_label, class: "badge #{rounded_class} #{style_class}"
    end
  end
end
