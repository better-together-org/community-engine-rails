# frozen_string_literal: true

module BetterTogether
  module Safety
    # Creates moderator actions for a safety case.
    class ActionsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_safety_case
      after_action :verify_authorized

      def create
        build_safety_action
        authorize @safety_action

        return persist_action if @safety_action.save

        render_case_show
      end

      private

      def build_safety_action
        @safety_action = @safety_case.actions.new(safety_action_params)
        @safety_action.actor = current_user.person
      end

      def persist_action
        sync_case_from_action!
        redirect_to_case('better_together.safety_actions.notices.created', 'Safety action recorded.')
      end

      def sync_case_from_action!
        @safety_case.update!(
          status: @safety_action.status_active? ? 'protective_action_in_effect' : @safety_case.status,
          review_at: @safety_action.review_at || @safety_case.review_at
        )
      end

      def render_case_show
        @safety_note = @safety_case.notes.new
        @safety_agreement = @safety_case.agreements.new
        render 'better_together/safety/cases/show', status: :unprocessable_entity
      end

      def redirect_to_case(key, default_message)
        redirect_to safety_case_path(@safety_case, locale: I18n.locale),
                    notice: t(key, default: default_message)
      end

      def set_safety_case
        @safety_case = policy_scope(BetterTogether::Safety::Case).find(params[:safety_case_id])
      end

      # rubocop:disable Metrics/MethodLength
      def safety_action_params
        params.require(:safety_action).permit(
          :action_type,
          :status,
          :reason,
          :details,
          :love_inclusivity_check,
          :solidarity_check,
          :accountability_check,
          :care_check,
          :values_review_notes,
          :requires_second_review,
          :approved_by_id,
          :review_at,
          :expires_at
        )
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
