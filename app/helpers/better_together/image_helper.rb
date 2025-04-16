# frozen_string_literal: true

module BetterTogether
  # Helps with rendering images for various entities
  module ImageHelper # rubocop:todo Metrics/ModuleLength
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/CyclomaticComplexity
    # rubocop:todo Metrics/AbcSize
    def cover_image_tag(entity, options = {}) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      image_classes = "cover-image rounded-top #{options[:class]}"
      image_style = options[:style].to_s
      image_width = options[:width] || 2400
      image_height = options[:height] || 600
      image_format = options[:format] || 'jpg'
      image_alt = options[:alt] || 'Cover Image'
      image_title = options[:title] || 'Cover Image'
      image_tag_attributes = {
        class: image_classes,
        style: image_style,
        alt: image_alt,
        title: image_title
      }

      # Determine if entity has a profile image
      if entity.respond_to?(:cover_image) && entity.cover_image.attached?
        attachment = if entity.respond_to?(:optimized_cover_image)
                       entity.optimized_cover_image
                     else
                       entity.cover_image_variant(image_width, image_height)
                     end

        image_tag(attachment.url, **image_tag_attributes)
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
      image_alt = options[:alt] || 'Card Image'
      image_title = options[:title] || 'Card Image'
      image_tag_attributes = {
        class: image_classes,
        style: image_style,
        alt: image_alt,
        title: image_title
      }

      # Determine if entity has a card image
      if entity.respond_to?(:card_image) && entity.card_image.attached?
        attachment = if entity.respond_to?(:optimized_card_image)
                       entity.optimized_card_image
                     else
                       entity.card_image_variant(image_width, image_height)
                     end

        image_tag(attachment.url, **image_tag_attributes)
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
      image_style = options[:style].to_s
      image_size = options[:size] || 300
      image_format = options[:format] || 'jpg'
      image_alt = options[:alt] || 'Profile Image'
      image_title = options[:title] || 'Profile Image'
      image_tag_attributes = {
        class: image_classes,
        style: image_style,
        alt: image_alt,
        title: image_title
      }

      # Determine if entity has a profile image
      if entity.respond_to?(:profile_image) && entity.profile_image.attached?
        attachment = if entity.respond_to?(:optimized_profile_image)
                       entity.optimized_profile_image
                     else
                       entity.profile_image_variant(image_size)
                     end

        image_tag(attachment.url, **image_tag_attributes)
      else
        # Use a default image based on the entity type
        default_image = default_profile_image(entity, image_format)
        image_tag(image_url(default_image), **image_tag_attributes)
      end
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
        image_tag(image.media, alt: name, class: 'img-fluid rounded mb-3')
      end
    end

    def render_image_grid(images, name)
      images.map do |image|
        content_tag(:div, class: 'col align-content-center col-md-4') do
          image_tag(image.media, alt: name, class: 'img-fluid rounded')
        end
      end.join.html_safe
    end

    private

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
