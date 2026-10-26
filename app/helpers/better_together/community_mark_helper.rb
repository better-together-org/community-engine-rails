# frozen_string_literal: true

module BetterTogether
  # The one image that stands for a community wherever it is shown: its logo, else its profile image, never both.
  module CommunityMarkHelper
    # [:logo, attachment], [:profile_image, attachment] or nil when the community has neither.
    def community_mark(community)
      if community.logo.attached?
        [:logo, community.optimized_logo]
      elsif community.profile_image.attached?
        [:profile_image, community.optimized_profile_image]
      end
    end

    # A small mark for a host, chip or picker row: a community's logo as a tile that keeps its shape, otherwise the
    # round profile image (a person's, or a community's when it has no logo). size is the height in pixels.
    def community_mark_tag(entity, size:, alt: '', title: nil, **options)
      kind, attachment = community_mark(entity) if entity.is_a?(BetterTogether::Community)
      return profile_mark_tag(entity, size:, alt:, title:, **options) unless kind == :logo

      tag.span(class: ['community-mark-tile', options[:class]], style: "--mark-size: #{size}px") do
        image_tag storage_proxy_url_for(attachment), alt:, title:
      end
    end

    private

    def profile_mark_tag(entity, size:, alt:, title:, **options)
      profile_image_tag(entity, class: options[:class], size: size * 2, alt:, title: title || alt,
                                style: "width: #{size}px; height: #{size}px; object-fit: cover;")
    end
  end
end
