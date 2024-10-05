
module BetterTogether
  # app/helpers/share_buttons_helper.rb
  module ShareButtonsHelper

    def share_buttons(platforms: BetterTogether::Metrics::Share::SHAREABLE_PLATFORMS, shareable: nil)
      url = request.original_url
      title = if shareable.respond_to? :title
        shareable&.title
      elsif shareable.respond_to? :name
        shareable&.name
      else
        I18n.t('better_together.share_buttons.default_title')
      end

      image = "" # TODO: set image

      # Generate the localized share tracking URL
      share_tracking_url = better_together.metrics_shares_path(locale: I18n.locale)

      # Pass the shareable_type and shareable_id if shareable is provided
      shareable_type = shareable&.class&.name
      shareable_id = shareable&.id

      content_tag :div, data: { controller: 'share' }, class: 'social-share-buttons' do
        heading = content_tag :div do
          content_tag :h5, I18n.t('better_together.share_buttons.share')
        end

        buttons = content_tag :div do
          platforms.map do |platform|
            link_to share_button_content(platform).html_safe, '#',
                    class: "btn btn-sm share-button share-#{platform}",
                    data: {
                      action: 'click->share#share',
                      platform: platform,
                      url: url,
                      title: title,
                      image: image,
                      share_tracking_url: share_tracking_url,
                      shareable_type: shareable_type,
                      shareable_id: shareable_id
                    },
                    aria: { label: I18n.t('better_together.share_buttons.aria_label', platform: platform.to_s.capitalize) },
                    rel: 'noopener noreferrer',
                    target: '_blank'
          end.join.html_safe
        end

        heading + buttons
      end
    end

    private

    def share_button_content(platform)
      # Use I18n translations for button content
      case platform.to_sym
      when :facebook
        "#{share_icon('facebook')}"
      when :twitter
        "#{share_icon('twitter')}"
      when :linkedin
        "#{share_icon('linkedin')}"
      when :pinterest
        "#{share_icon('pinterest')}"
      when :reddit
        "#{share_icon('reddit')}"
      when :whatsapp
        "#{share_icon('whatsapp')}"
      else
        I18n.t('better_together.share_buttons.share')
      end
    end

    def share_icon(platform)
      # Replace with actual SVG icons or use a helper/library like FontAwesome
      case platform
      when 'facebook'
        '<i class="fab fa-facebook" ></i>'.html_safe
      when 'twitter'
        '<i class="fab fa-twitter" ></i>'.html_safe
      when 'linkedin'
        '<i class="fab fa-linkedin" ></i>'.html_safe
      when 'pinterest'
        '<i class="fab fa-pinterest" ></i>'.html_safe
      when 'reddit'
        '<i class="fab fa-reddit-alien" ></i>'.html_safe
      when 'whatsapp'
        '<i class="fab fa-whatsapp" ></i>'.html_safe
      else
        ''.html_safe
      end
    end
  end
end