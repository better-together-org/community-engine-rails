# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Custom controller for platform metrics summary
      # Provides aggregated metrics data for dashboard display
      # Requires manage_platform permission
      class MetricsSummaryController < BetterTogether::Api::ApplicationController
        skip_after_action :enforce_policy_use

        # GET /api/v1/metrics/summary
        def show # rubocop:disable Metrics/MethodLength
          unless current_user&.person&.permitted_to?('manage_platform')
            return render json: { errors: [{ status: '403', title: 'Forbidden' }] }, status: :forbidden
          end

          @policy_used = true

          from_date = parse_date(params[:from_date])
          to_date = parse_date(params[:to_date])

          scope = build_scope(from_date, to_date)

          render json: {
            data: {
              type: 'metrics_summary',
              id: 'current',
              attributes: build_attributes(scope, from_date, to_date)
            }
          }
        end

        private

        def parse_date(value)
          Date.parse(value) if value.present?
        rescue Date::Error
          nil
        end

        def build_scope(from_date, to_date)
          scope = BetterTogether::Metrics::PageView.all
          scope = scope.where('viewed_at >= ?', from_date) if from_date
          scope = scope.where('viewed_at <= ?', to_date) if to_date
          scope
        end

        def build_attributes(scope, from_date, to_date) # rubocop:disable Metrics/MethodLength
          {
            total_page_views: scope.count,
            unique_pages: scope.distinct.count(:page_url),
            views_by_locale: scope.group(:locale).count,
            top_pages: top_pages(scope),
            period_start: (from_date || scope.minimum(:viewed_at))&.to_s,
            period_end: (to_date || scope.maximum(:viewed_at))&.to_s
          }
        end

        def top_pages(scope)
          scope.group(:page_url)
               .order(Arel.sql('count(*) DESC'))
               .limit(20)
               .count
        end
      end
    end
  end
end
