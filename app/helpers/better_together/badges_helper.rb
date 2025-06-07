# frozen_string_literal: true

module BetterTogether
  # Helpers for Badges
  module BadgesHelper
    def categories_badge(entity, rounded: true, style: 'info')
      return unless entity.respond_to?(:categories) && entity.categories.any?

      entity.categories.map do |category|
        create_badge(category.name, rounded: rounded, style: style)
      end.join(' ').html_safe
    end

    def privacy_badge(entity, rounded: true, style: 'primary')
      return unless entity.respond_to? :privacy

      create_badge(entity.privacy.humanize.capitalize, rounded: rounded, style: style)
    end

    private

    def create_badge(label, rounded: true, style: 'primary')
      rounded_class = rounded ? 'rounded-pill' : ''
      style_class = "text-bg-#{style}"

      content_tag :span, label, class: "badge #{rounded_class} #{style_class}"
    end
  end
end
