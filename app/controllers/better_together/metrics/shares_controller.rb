# app/controllers/better_together/metrics/shares_controller.rb
module BetterTogether
  module Metrics
    class SharesController < ApplicationController
      # Disable CSRF protection for API endpoints if using token-based auth
      protect_from_forgery with: :null_session

      def create
        platform = params[:platform]
        url = params[:url]
        shareable_type = params[:shareable_type]
        shareable_id = params[:shareable_id]
        locale = I18n.locale.to_s

        # Validate platform and URL
        unless valid_platform?(platform) && valid_url?(url)
          render json: { error: I18n.t('metrics.shares.invalid_parameters') }, status: :unprocessable_entity and return
        end

        # Enqueue the TrackShareJob
        BetterTogether::Metrics::TrackShareJob.perform_later(platform, url, locale, shareable_type, shareable_id)

        # Respond with success
        render json: { success: true }, status: :ok
      end

      private

      def valid_platform?(platform)
        Share::SHAREABLE_PLATFORMS.include?(platform)
      end

      def valid_url?(url)
        uri = URI.parse(url)
        %w[http https].include?(uri.scheme)
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
