# frozen_string_literal: true

module BetterTogether
  module Metrics
    class PageViewsController < ApplicationController # rubocop:todo Style/Documentation
      def create
        viewable_type = params[:viewable_type]
        viewable_id = params[:viewable_id]
        locale = params[:locale]

        allowed_types = BetterTogether::Metrics::Viewable.included_in_models.map(&:name)
        unless allowed_types.include?(viewable_type)
          render json: { error: 'Invalid viewable' }, status: :unprocessable_entity and return
        end

        viewable = viewable_type.constantize.find_by(id: viewable_id)
        unless viewable
          render json: { error: 'Invalid viewable' }, status: :unprocessable_entity and return
        end

        BetterTogether::Metrics::TrackPageViewJob.perform_later(viewable, locale)
        render json: { success: true }, status: :ok
      end
    end
  end
end

