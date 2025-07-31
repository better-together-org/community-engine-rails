# frozen_string_literal: true

module BetterTogether
  module Metrics
    class PageViewsController < ApplicationController # rubocop:todo Style/Documentation
      def create
        viewable_type = params[:viewable_type]
        viewable_id = params[:viewable_id]
        locale = params[:locale]

        allowed_models = BetterTogether::Metrics::Viewable.included_in_models.index_by(&:name)
        model_class = allowed_models[viewable_type]
        unless model_class
          render json: { error: 'Invalid viewable' }, status: :unprocessable_entity and return
        end

        viewable = model_class.find_by(id: viewable_id)
        unless viewable
          render json: { error: 'Invalid viewable' }, status: :unprocessable_entity and return
        end

        BetterTogether::Metrics::TrackPageViewJob.perform_later(viewable, locale)
        render json: { success: true }, status: :ok
      end
    end
  end
end

