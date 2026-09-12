# frozen_string_literal: true

module BetterTogether
  # app/helpers/share_buttons_helper.rb
  module ShareButtonsHelper # rubocop:todo Metrics/ModuleLength
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    def share_buttons(platforms: BetterTogether::Metrics::Share::SHAREABLE_PLATFORMS, shareable: nil)
      url = share_button_url
      title = if shareable.respond_to? :title
                shareable&.title
              elsif shareable.respond_to? :name
                shareable&.name
              else
                I18n.t('better_together.share_buttons.default_title')
              end

      image = '' # TODO: set image

      # Generate the localized share tracking URL
      share_tracking_url = better_together.metrics_shares_path(locale: I18n.locale)

      # Pass the shareable_type and shareable_id if shareable is provided
      shareable_type = shareable&.class&.name
      shareable_id = shareable&.id

      content_tag :div, data: { controller: 'better_together--share' }, class: 'social-share-buttons' do
        heading = content_tag :div do
          content_tag :h5, I18n.t('better_together.share_buttons.share')
        end

        buttons = content_tag :div do
          short_link_btn = shortlinkable_share_button(shareable) if shareable.respond_to?(:ensure_short_link!)
          social_btns = platforms.map do |platform|
            link_to share_button_content(platform).html_safe, "#share-#{platform}",
                    class: "share-button share-#{platform}",
                    data: {
                      action: 'click->better_together--share#share',
                      platform:,
                      url:,
                      title:,
                      image:,
                      share_tracking_url:,
                      shareable_type: shareable_type.to_s,
                      shareable_id:
                    },
                    # rubocop:todo Layout/LineLength
                    aria: { label: I18n.t('better_together.share_buttons.aria_label', platform: platform.to_s.capitalize) },
                    # rubocop:enable Layout/LineLength
                    rel: 'noopener noreferrer',
                    target: '_blank'
          end
          safe_join([short_link_btn, *social_btns].compact)
        end

        heading + buttons
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    private

    def share_button_url
      if respond_to?(:canonical_current_url, true)
        send(:canonical_current_url)
      else
        request.original_url
      end
    end

    def shortlinkable_share_button(shareable) # rubocop:disable Metrics/MethodLength
      frame_id = "sl-#{dom_id(shareable)}"
      existing = shareable.short_link&.active_and_unexpired? ? shareable.short_link : nil

      content_tag :'turbo-frame', id: frame_id do
        if existing
          render partial: 'better_together/short_links/share_link_button',
                 locals: { shareable:, short_link: existing }
        else
          button_to ensure_content_short_link_path,
                    params: { linkable_type: shareable.class.name, linkable_id: shareable.id },
                    class: 'share-button share-short-link',
                    form: { data: { turbo_frame: frame_id } },
                    title: t('better_together.share_buttons.get_short_link'),
                    aria: { label: t('better_together.share_buttons.get_short_link') } do
            short_link_icon
          end
        end
      end
    end

    def short_link_icon
      content_tag :div, class: 'fa-stack fa-2x' do
        content_tag(:i, '', class: 'bg fas fa-circle fa-stack-2x', aria: { hidden: 'true' }) +
          content_tag(:i, '', class: 'fa-stack-1x icon fas fa-link', aria: { hidden: 'true' })
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def share_button_content(platform) # rubocop:todo Metrics/MethodLength
      # Use I18n translations for button content
      case platform.to_sym
      when :email
        share_icon('email').to_s
      when :facebook
        share_icon('facebook').to_s
      when :bluesky
        share_icon('bluesky').to_s
      when :linkedin
        share_icon('linkedin').to_s
      when :pinterest
        share_icon('pinterest').to_s
      when :reddit
        share_icon('reddit').to_s
      when :whatsapp
        share_icon('whatsapp').to_s
      else
        I18n.t('better_together.share_buttons.share')
      end
    end

    def share_icon(platform) # rubocop:todo Metrics/MethodLength
      # rubocop:disable Metrics/CyclomaticComplexity
      content_tag :div, class: 'fa-stack fa-2x', role: 'img' do
        bg = content_tag :i, '', class: 'bg fas fa-circle fa-stack-2x'

        icon =
          # Replace with actual SVG icons or use a helper/library like FontAwesome
          case platform
          when 'email'
            '<i class="fa-stack-1x icon fas fa-envelope" ></i>'.html_safe
          when 'facebook'
            '<i class="fa-stack-1x icon fab fa-facebook" ></i>'.html_safe
          when 'bluesky'
            '<i class="fa-stack-1x icon fab fa-bluesky" ></i>'.html_safe
          when 'linkedin'
            '<i class="fa-stack-1x icon fab fa-linkedin" ></i>'.html_safe
          when 'pinterest'
            '<i class="fa-stack-1x icon fab fa-pinterest" ></i>'.html_safe
          when 'reddit'
            '<i class="fa-stack-1x icon fab fa-reddit-alien" ></i>'.html_safe
          when 'whatsapp'
            '<i class="fa-stack-1x icon fab fa-whatsapp" ></i>'.html_safe
          else
            ''.html_safe
          end

        bg + icon
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  end
end
