# app/controllers/better_together/metrics/link_clicks_controller.rb
module BetterTogether
  module Metrics
    class LinkClicksController < ApplicationController
      # Disable CSRF protection for API endpoints if using token-based auth
      protect_from_forgery with: :null_session

      def create
        url = params[:url]
        page_url = params[:page_url]  # Get the page URL where the link was clicked
        internal = params[:internal] == "true"
        locale = params[:locale]

        # Enqueue the background job
        BetterTogether::Metrics::TrackLinkClickJob.perform_later(url, page_url, locale, internal)

        # Respond with success
        render json: { success: true }, status: :ok
      end
    end
  end
end
