# frozen_string_literal: true

module BetterTogether
  # Centralizes same-origin proxy URL generation for ActiveStorage-backed media.
  class MediaUrlBuilder
    class << self
      def proxy_path_for(attachment_or_variant, **)
        Rails.application.routes.url_helpers.rails_storage_proxy_path(
          attachment_or_variant,
          only_path: true,
          **
        )
      end

      def proxy_url_for(attachment_or_variant, base_url: nil, url_options: {}, **)
        if base_url.present?
          "#{base_url.delete_suffix('/')}#{proxy_path_for(attachment_or_variant, **)}"
        elsif url_options.present?
          Rails.application.routes.url_helpers.rails_storage_proxy_url(
            attachment_or_variant,
            **url_options,
            **
          )
        else
          Rails.application.routes.url_helpers.rails_storage_proxy_url(
            attachment_or_variant,
            **
          )
        end
      end
    end
  end
end
