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

    # True only when rendering a mailer view (controller is the ActionMailer::Base
    # instance there, same as it's the real controller for an ordinary request) —
    # false for a normal browser-rendered page and for Comment's bare
    # broadcast_append_later_to render, both of which have the app's own CSS
    # already loaded and should stay in charge of sizing.
    def mailer_view?
      respond_to?(:controller) && controller.is_a?(ActionMailer::Base)
    end

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/CyclomaticComplexity
    # rubocop:todo Metrics/AbcSize
    def profile_image_tag(entity, options = {}) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      image_classes = "profile-image rounded-circle #{options[:class]}"
      image_size = options[:size] || 300
      image_format = options[:format] || 'jpg'
      image_alt = options[:alt] || 'Profile Image'
      image_title = options[:title] || 'Profile Image'
      # width/height attributes are always safe to add — the app's CSS (which sets
      # size per context/class) always wins over a bare HTML attribute, same as a UA
      # default. An inline *style*, though, beats app CSS on specificity, so that's
      # only added in a mailer view — most email clients strip <style>/external
      # stylesheets and only honor inline styles and width/height attributes, unlike
      # a normal browser-rendered page where the app's own CSS should stay in charge.
      inline_style = options[:style].to_s
      inline_style = "width: #{image_size}px; height: #{image_size}px; object-fit: cover; #{inline_style}".strip if mailer_view?
      image_tag_attributes = {
        class: image_classes,
        style: inline_style,
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

    GALLERY_LAYOUTS = %i[grid masonry].freeze
    GALLERY_VARIANT_WIDTHS = [480, 960].freeze
    GALLERY_FULL_WIDTH = 1600
    LIGHTBOX = 'better_together--lightbox'
    GALLERY_SIZES = '(min-width: 768px) 33vw, 100vw'

    # Renders a gallery of image blocks (anything responding to #media).
    # Per-image alt_text, caption and attribution are used when present; name is the fallback alt text.
    # layout: :grid (default, DOM order equals visual order) or :masonry (opt-in).
    # lightbox: true turns each thumbnail into a button that opens the image in a modal viewer.
    def render_image_gallery(images, name, layout: :grid, label: nil, lightbox: false)
      return if images.blank?

      layout = GALLERY_LAYOUTS.include?(layout&.to_sym) ? layout.to_sym : :grid
      images = images.to_a
      content_tag(:section, class: "image-gallery image-gallery--#{layout} mb-4",
                            'aria-label': label.presence || name.to_s.presence, **gallery_lightbox_data(lightbox)) do
        safe_join([gallery_list(images, name, layout, lightbox),
                   (gallery_lightbox_modal(name, label) if lightbox)].compact)
      end
    end

    def gallery_list(images, name, layout, lightbox)
      content_tag(:ul, class: 'image-gallery__list list-unstyled mb-0', **gallery_data(layout)) do
        safe_join(images.each_with_index.map do |image, index|
          render_gallery_item(image, name, single: images.size == 1,
                                           lightbox: lightbox ? { index:, total: images.size } : nil)
        end)
      end
    end

    def render_gallery_item(image, name, single: false, lightbox: nil)
      content_tag(:li, class: "image-gallery__item#{' image-gallery__item--single' if single}") do
        content_tag(:figure, class: 'image-gallery__figure m-0') do
          picture = gallery_image_tag(image, name, single:)
          picture = gallery_lightbox_button(image, name, picture, **lightbox) if lightbox
          safe_join([picture, gallery_caption(image)].compact)
        end
      end
    end

    def render_single_image(image, name)
      content_tag(:div, class: 'col col-12') do
        image_tag(storage_proxy_url_for(image.media), alt: gallery_alt(image, name), class: 'img-fluid rounded mb-3')
      end
    end

    def render_image_grid(images, name)
      safe_join(images.map do |image|
        content_tag(:div, class: 'col align-content-center col-md-4') do
          image_tag(storage_proxy_url_for(image.media), alt: gallery_alt(image, name), class: 'img-fluid rounded')
        end
      end)
    end

    private

    def gallery_data(layout)
      return {} unless layout == :masonry

      { 'data-controller': 'better_together--masonry',
        'data-better_together--masonry-item-selector-value': '.image-gallery__item' }
    end

    # Stimulus names contain underscores, which the data: hash would turn into dashes, so write full attributes.
    def lightbox_target(name)
      { "data-#{LIGHTBOX}-target": name }
    end

    def gallery_lightbox_data(lightbox)
      return {} unless lightbox

      { 'data-controller': LIGHTBOX,
        "data-#{LIGHTBOX}-counter-template-value": t('better_together.image_gallery.counter') }
    end

    def gallery_lightbox_button(image, name, picture, index:, total:)
      alt = gallery_alt(image, name)
      full = storage_proxy_url_for(gallery_variant(image.media, GALLERY_FULL_WIDTH))
      content_tag(:button, picture, type: 'button', class: 'image-gallery__open btn p-0 border-0 d-block w-100',
                                    'aria-label': t('better_together.image_gallery.open_image',
                                                    current: index + 1, total:, name: alt),
                                    'data-action': "click->#{LIGHTBOX}#open", 'data-full-src': full, 'data-alt': alt,
                                    **lightbox_target('trigger'))
    end

    def gallery_lightbox_modal(name, label)
      title_id = "image-gallery-title-#{SecureRandom.hex(4)}"
      title = t('better_together.image_gallery.dialog_label', name: label.presence || name)
      content_tag(:div, class: 'modal fade image-gallery__modal', tabindex: -1,
                        'aria-labelledby': title_id, 'aria-hidden': true,
                        'data-action': "keydown->#{LIGHTBOX}#keydown", **lightbox_target('modal')) do
        content_tag(:div, class: 'modal-dialog modal-xl modal-dialog-centered') do
          content_tag(:div, class: 'modal-content bg-dark text-white') do
            safe_join([gallery_modal_header(title_id, title), gallery_modal_body, gallery_modal_footer])
          end
        end
      end
    end

    def gallery_modal_header(title_id, title)
      content_tag(:div, class: 'modal-header border-0') do
        safe_join([
                    content_tag(:h2, title, id: title_id, class: 'visually-hidden'),
                    content_tag(:span, '', class: 'image-gallery__counter small', 'aria-live': 'polite',
                                           **lightbox_target('counter')),
                    content_tag(:button, '', type: 'button', class: 'btn-close btn-close-white',
                                             'data-bs-dismiss': 'modal',
                                             'aria-label': t('better_together.image_gallery.close'))
                  ])
      end
    end

    def gallery_modal_body
      content_tag(:div, class: 'modal-body text-center') do
        safe_join([
                    tag.img(src: '', alt: '', class: 'image-gallery__modal-image img-fluid', **lightbox_target('image')),
                    content_tag(:p, '', class: 'image-gallery__modal-caption small mt-2 mb-0',
                                        **lightbox_target('caption'))
                  ])
      end
    end

    def gallery_modal_footer
      content_tag(:div, class: 'modal-footer border-0 justify-content-between') do
        safe_join([gallery_nav_button('previous', 'fa-chevron-left'), gallery_nav_button('next', 'fa-chevron-right')])
      end
    end

    def gallery_nav_button(direction, icon)
      content_tag(:button, tag.i(class: "fas #{icon}", 'aria-hidden': true), type: 'button',
                                                                             class: "btn btn-outline-light image-gallery__#{direction}",
                                                                             'aria-label': t("better_together.image_gallery.#{direction}"),
                                                                             'data-action': "click->#{LIGHTBOX}##{direction}")
    end

    def gallery_alt(image, name)
      image.try(:alt_text).presence || name.to_s
    end

    def gallery_image_tag(image, name, single:)
      media = image.media
      width, height = gallery_dimensions(media)
      image_tag(storage_proxy_url_for(gallery_variant(media, GALLERY_VARIANT_WIDTHS.last)),
                alt: gallery_alt(image, name), class: 'image-gallery__image img-fluid rounded',
                loading: 'lazy', decoding: 'async', width:, height:,
                srcset: gallery_srcset(media, width), sizes: (single ? '100vw' : GALLERY_SIZES))
    end

    def gallery_variant(media, width)
      media.variable? ? media.variant(resize_to_limit: [width, width]) : media
    end

    # Variants are only offered for formats libvips can resize; others (SVG, GIF) load as-is.
    def gallery_srcset(media, original_width)
      return unless media.variable? && original_width

      widths = GALLERY_VARIANT_WIDTHS.select { |w| w < original_width }
      widths.map { |w| "#{storage_proxy_url_for(gallery_variant(media, w))} #{w}w" }.join(', ').presence
    end

    # Width and height of the largest rendition, so the browser can reserve space before loading.
    def gallery_dimensions(media)
      meta = media.blob.metadata
      width = meta['width']
      height = meta['height']
      return [nil, nil] unless width && height && media.variable?

      limit = GALLERY_VARIANT_WIDTHS.last
      scale = [limit.to_f / [width, height].max, 1.0].min
      [(width * scale).round, (height * scale).round]
    end

    def gallery_caption(image)
      caption = image.try(:caption).presence
      attribution = image.try(:attribution).presence
      return if caption.blank? && attribution.blank?

      content_tag(:figcaption, class: 'image-gallery__caption small text-muted mt-1') do
        safe_join([caption, gallery_attribution(image, attribution)].compact, ' ')
      end
    end

    def gallery_attribution(image, attribution)
      return if attribution.blank?

      url = image.try(:attribution_url).presence
      text = url ? link_to(attribution, url, rel: 'noopener', target: '_blank') : attribution
      content_tag(:span, text, class: 'image-gallery__attribution')
    end

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
