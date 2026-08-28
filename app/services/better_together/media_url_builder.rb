# frozen_string_literal: true

module BetterTogether
  # Centralizes same-origin proxy URL generation for ActiveStorage-backed media.
  class MediaUrlBuilder
    class << self
      # rubocop:disable Style/ArgumentsForwarding
      def proxy_path_for(attachment_or_variant, **options)
        Rails.application.routes.url_helpers.rails_storage_proxy_path(
          attachment_or_variant,
          only_path: true,
          **options
        )
      end

      def proxy_url_for(attachment_or_variant, base_url: nil, url_options: {}, **options)
        if base_url.present?
          "#{base_url.delete_suffix('/')}#{proxy_path_for(attachment_or_variant, **options)}"
        elsif url_options[:host].present?
          Rails.application.routes.url_helpers.rails_storage_proxy_url(
            attachment_or_variant,
            **url_options,
            **options
          )
        else
          proxy_path_for(
            attachment_or_variant,
            **options
          )
        end
      end
      # rubocop:enable Style/ArgumentsForwarding
    end
  end
end
