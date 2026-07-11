# frozen_string_literal: true

module BetterTogether
  # Helps with rendering images for various entities
  module ImageHelper # rubocop:todo Metrics/ModuleLength
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/CyclomaticComplexity
    # rubocop:todo Metrics/AbcSize
    def cover_image_tag(entity, options = {}) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      image_classes = "cover-image #{options[:class]}"
      image_style = options[:style].to_s
      image_width = options[:width] || 2400
      image_height = options[:height] || 600
      image_format = options[:format] || 'jpg'
      image_alt = options[:alt] || entity&.to_s || entity&.name || 'Cover image'
      image_title = options[:title] || entity&.to_s || entity&.name || 'Cover image'
      image_tag_attributes = {
        class: image_classes,
        style: image_style,
        alt: image_alt,
        title: image_title
      }

      # Determine if entity has a profile image
      if entity.respond_to?(:cover_image) && entity.cover_image.attached?
        attachment = cover_image_attachment_for(entity, image_width, image_height)

        image_tag(storage_proxy_url_for(attachment), **image_tag_attributes)
      elsif (category = first_category_with_cover_image(entity))
        attachment = cover_image_attachment_for(category, image_width, image_height)
        image_tag(storage_proxy_url_for(attachment), **image_tag_attributes)
      else
        # Use a default image based on the entity type
        default_image = default_cover_image(entity, image_format)
        image_tag(image_url(default_image), **image_tag_attributes)
      end
    end

    def card_image_tag(entity, options = {}) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      image_classes = "card-img-top #{options[:class]}"
      image_style = options[:style].to_s
      image_width = options[:width] || 1200
      image_height = options[:height] || 800
      image_format = options[:format] || 'jpg'
      image_alt = options[:alt] || entity&.to_s || entity&.name || 'Card image'
      image_title = options[:title] || entity&.to_s || entity&.name || 'Card image'
      image_tag_attributes = {
        class: image_classes,
        style: image_style,
        alt: image_alt,
        title: image_title
      }

      # Determine if entity has a card image
      if entity.respond_to?(:card_image) && entity.card_image&.attached?
        attachment = card_image_attachment_for(entity, image_width, image_height)

        image_tag(storage_proxy_url_for(attachment), **image_tag_attributes)
      elsif (category = first_category_with_cover_image(entity))
        attachment = cover_image_attachment_for(category, image_width, image_height)
        image_tag(storage_proxy_url_for(attachment), **image_tag_attributes)
      else
        # Use a default image based on the entity type
        default_image = default_card_image(entity, image_format)
        image_tag(image_url(default_image), **image_tag_attributes)
      end
    end

    def default_card_image(entity, image_format)
      case entity.class.name
      when 'BetterTogether::Person'
        "card_images/default_card_image_person.#{image_format}"
      when 'BetterTogether::Community'
        "card_images/default_card_image_community.#{image_format}"
      else
        "card_images/default_card_image_generic.#{image_format}"
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/CyclomaticComplexity
    # rubocop:todo Metrics/AbcSize
    def profile_image_tag(entity, options = {}) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      image_classes = "profile-image rounded-circle #{options[:class]}"
      image_size = options[:size] || 300
      image_format = options[:format] || 'jpg'
      image_alt = options[:alt] || 'Profile Image'
      image_title = options[:title] || 'Profile Image'
      # width/height attributes plus an inline size style (not just the CSS class) so
      # this renders at the correct size in a mailer view — most email clients strip
      # <style>/external stylesheets and only honor inline styles and width/height
      # attributes, unlike a normal browser-rendered page.
      size_style = "width: #{image_size}px; height: #{image_size}px; object-fit: cover;"
      image_tag_attributes = {
        class: image_classes,
        style: "#{size_style} #{options[:style]}".strip,
        width: image_size,
        height: image_size,
        alt: image_alt,
        title: image_title
      }

      image_url = profile_image_url(entity, size: image_size, format: image_format)
      image_tag(image_url, **image_tag_attributes)
    rescue ActiveStorage::FileNotFoundError
      image_url = profile_image_url(entity, size: image_size, format: image_format)
      image_tag(image_url, **image_tag_attributes)
    end

    def profile_image_url(entity, size: 300, format: 'jpg')
      image_size = size || 300
      image_format = format || 'jpg'

      if entity.respond_to?(:profile_image) && entity.profile_image.attached?
        attachment = profile_image_attachment_for(entity, image_size)
        url = storage_proxy_url_for(attachment) if attachment
        return url if url.present?
      end

      default_profile_image_url(entity, image_format)
    rescue ActiveStorage::FileNotFoundError
      default_profile_image_url(entity, image_format)
    end

    # image_url resolves an absolute URL from the current request automatically, but
    # there's no request in a mailer (or Comment's bare broadcast_append_later_to
    # render) — it falls back to a host-relative path there, broken in an email with
    # no current page to resolve against. Build the absolute URL from url_options
    # (the mailer's platform-derived host) directly in that case instead.
    def default_profile_image_url(entity, image_format)
      path = default_profile_image(entity, image_format)
      return image_url(path) if respond_to?(:request) && request.present?

      host = url_options[:host]
      return image_path(path) unless host.present?

      protocol = url_options[:protocol] || 'http'
      port_suffix = url_options[:port] ? ":#{url_options[:port]}" : ''
      "#{protocol}://#{host}#{port_suffix}#{image_path(path)}"
    end

    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    def render_image_gallery(images, name)
      return if images.blank?

      content_tag(:section, class: 'image-gallery mb-4', data: { controller: 'better_together--masonry' }) do
        content_tag(:div, class: 'row g-3') do
          images.size == 1 ? render_single_image(images.first, name) : render_image_grid(images, name)
        end
      end
    end

    def render_single_image(image, name)
      content_tag(:div, class: 'col col-12') do
        image_tag(storage_proxy_url_for(image.media), alt: name, class: 'img-fluid rounded mb-3')
      end
    end

    def render_image_grid(images, name)
      safe_join(images.map do |image|
        content_tag(:div, class: 'col align-content-center col-md-4') do
          image_tag(storage_proxy_url_for(image.media), alt: name, class: 'img-fluid rounded')
        end
      end)
    end

    private

    def first_category_with_cover_image(entity)
      return unless entity.respond_to?(:categories)

      categories_association = association_for(entity, :categories)

      if categories_association&.loaded?
        entity.categories.find { |category| attachment_present?(category, :cover_image_attachment, :cover_image) }
      else
        entity.categories.with_cover_images.first
      end
    end

    def attachment_present?(record, attachment_association, attachment_name)
      attachment_association_reflection = association_for(record, attachment_association)
      return attachment_association_reflection.target.present? if attachment_association_reflection&.loaded?

      record.respond_to?(attachment_name) && record.public_send(attachment_name).attached?
    end

    def association_for(record, association_name)
      return unless record.respond_to?(:association)
      return unless record.class.reflect_on_association(association_name)

      record.association(association_name)
    end

    def profile_image_attachment_for(entity, image_size)
      return unless entity.respond_to?(:profile_image) && entity.profile_image.attached?

      if entity.respond_to?(:optimized_profile_image)
        entity.optimized_profile_image
      elsif entity.respond_to?(:profile_image_variant)
        entity.profile_image_variant(image_size)
      elsif entity.profile_image.content_type == 'image/svg+xml'
        entity.profile_image
      else
        entity.profile_image.variant(resize_to_fill: [image_size, image_size])
      end
    end

    def cover_image_attachment_for(entity, image_width, image_height)
      return unless entity.respond_to?(:cover_image) && entity.cover_image.attached?

      if entity.respond_to?(:optimized_cover_image)
        entity.optimized_cover_image
      elsif entity.respond_to?(:cover_image_variant)
        entity.cover_image_variant(image_width, image_height)
      elsif entity.cover_image.content_type == 'image/svg+xml'
        entity.cover_image
      else
        entity.cover_image.variant(resize_to_fill: [image_width, image_height])
      end
    end

    def card_image_attachment_for(entity, image_width, image_height)
      return unless entity.respond_to?(:card_image) && entity.card_image&.attached?

      if entity.respond_to?(:optimized_card_image)
        entity.optimized_card_image
      elsif entity.respond_to?(:card_image_variant)
        entity.card_image_variant(image_width, image_height)
      elsif entity.card_image.content_type == 'image/svg+xml'
        entity.card_image
      else
        entity.card_image.variant(resize_to_fill: [image_width, image_height])
      end
    end

    def default_cover_image(entity, image_format)
      case entity.class.name
      when 'BetterTogether::Person'
        "cover_images/default_cover_image_person.#{image_format}"
      when 'BetterTogether::Community'
        "cover_images/default_cover_image_community.#{image_format}"
      else
        "cover_images/default_cover_image_generic.#{image_format}"
      end
    end

    def default_profile_image(entity, image_format)
      case entity.class.name
      when 'BetterTogether::Person'
        "profile_images/default_profile_image_person.#{image_format}"
      when 'BetterTogether::Community'
        "profile_images/default_profile_image_community.#{image_format}"
      else
        "profile_images/default_profile_image_generic.#{image_format}"
      end
    end
  end
end
