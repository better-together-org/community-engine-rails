# frozen_string_literal: true

module BetterTogether
  module Safety
    # Lists and updates safety cases for moderators and reporters.
    class CasesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_safety_case, only: %i[show update]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Safety::Case

        @safety_cases = filtered_safety_cases
        @content_security_review_items = content_security_review_items
        @local_review_snapshot = local_review_snapshot
      end

      def show
        authorize @safety_case

        @safety_action = @safety_case.actions.new
        @safety_note = @safety_case.notes.new
        @safety_agreement = @safety_case.agreements.new
      end

      def update
        authorize @safety_case

        if @safety_case.update(safety_case_params)
          set_resolved_at_if_needed
          redirect_to safety_case_path(@safety_case, locale: I18n.locale),
                      notice: t('better_together.safety_cases.notices.updated', default: 'Safety case was updated.')
        else
          prepare_case_resources
          render :show, status: :unprocessable_entity
        end
      end

      private

      def review_platform
        @review_platform ||= ::Current.platform || ::Current.host_platform || ::BetterTogether::Platform.find_by(host: true)
      end

      def content_security_review_items
        BetterTogether::ContentSecurity::Subject
          .for_platform(review_platform)
          .review_queue
          .includes(:active_storage_blob)
          .limit(10)
      end

      def local_review_snapshot
        Rails.cache.fetch(
          BetterTogether::Safety::LocalReviewSnapshotService.cache_key_for(review_platform),
          expires_in: 15.minutes
        ) do
          BetterTogether::Safety::LocalReviewSnapshotService.new(
            case_scope: policy_scope(BetterTogether::Safety::Case),
            report_scope: policy_scope(BetterTogether::Report),
            content_security_subject_scope: BetterTogether::ContentSecurity::Subject.for_platform(review_platform)
          ).call
        end
      end

      def filtered_safety_cases
        scope = policy_scope(BetterTogether::Safety::Case)
                .includes(:report, :assigned_reviewer)
                .recent_first

        %i[status lane harm_level].reduce(scope) do |relation, filter|
          params[filter].present? ? relation.where(filter => params[filter]) : relation
        end
      end

      def set_resolved_at_if_needed
        return unless @safety_case.status_resolved? && @safety_case.resolved_at.blank?

        @safety_case.update(resolved_at: Time.current)
      end

      def prepare_case_resources
        @safety_action = @safety_case.actions.new
        @safety_note = @safety_case.notes.new
        @safety_agreement = @safety_case.agreements.new
      end

      def set_safety_case
        @safety_case = policy_scope(BetterTogether::Safety::Case).find(params[:id])
      end

      def safety_case_params
        params.require(:safety_case).permit(
          :status,
          :lane,
          :assigned_reviewer_id,
          :closure_type,
          :closure_summary,
          :review_at
        )
      end
    end
  end
end
