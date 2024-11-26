# frozen_string_literal: true

# app/controllers/better_together/metrics/link_clicks_controller.rb
module BetterTogether
  module Metrics
    class LinkClicksController < ApplicationController # rubocop:todo Style/Documentation
      # Disable CSRF protection for API endpoints if using token-based auth
      protect_from_forgery with: :null_session

      def create
        url = params[:url]
        page_url = params[:page_url] # Get the page URL where the link was clicked
        locale = params[:locale]

        # Check if the link is internal by comparing the host of the URL with the request host
        internal = internal_link?(url)

        # Enqueue the background job
        BetterTogether::Metrics::TrackLinkClickJob.perform_later(url, page_url, locale, internal)

        # Respond with success
        render json: { success: true }, status: :ok
      end

      private

      def internal_link?(url)
        # Use URI to parse the URL and compare the host with the request host
        URI.parse(url).host == request.host
      rescue URI::InvalidURIError
        # If URL parsing fails, assume it’s external to handle errors gracefully
        false
      end
    end
  end
end
