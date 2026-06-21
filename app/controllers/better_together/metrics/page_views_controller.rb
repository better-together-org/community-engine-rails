# frozen_string_literal: true

module BetterTogether
  module Metrics
    class PageViewsController < ApplicationController # rubocop:todo Style/Documentation
      include PlatformContext

      def create # rubocop:todo Metrics/AbcSize
        viewable_type = params[:viewable_type]
        viewable_id = params[:viewable_id]
        locale = params[:locale]

        allowed_models = BetterTogether::Metrics::Viewable.included_in_models.index_by(&:name)
        model_class = allowed_models[viewable_type]
        render json: { error: 'Invalid viewable' }, status: :unprocessable_content and return unless model_class

        viewable = model_class.find_by(id: viewable_id)
        render json: { error: 'Invalid viewable' }, status: :unprocessable_content and return unless viewable

        BetterTogether::Metrics::TrackPageViewJob.perform_later(viewable, locale, metrics_platform.id, metrics_logged_in?)
        render json: { success: true }, status: :ok
      end
    end
  end
end
