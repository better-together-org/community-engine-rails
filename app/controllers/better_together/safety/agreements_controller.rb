# frozen_string_literal: true

module BetterTogether
  module Safety
    # Creates and updates restorative agreements for a safety case.
    class AgreementsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_safety_case
      before_action :set_safety_agreement, only: :update
      after_action :verify_authorized

      def create
        build_safety_agreement
        authorize @safety_agreement

        return persist_created_agreement if @safety_agreement.save

        render_case_show
      end

      def update
        authorize @safety_agreement

        return persist_updated_agreement if @safety_agreement.update(safety_agreement_params)

        render_case_show
      end

      private

      def build_safety_agreement
        @safety_agreement = @safety_case.agreements.new(safety_agreement_params)
        @safety_agreement.created_by = current_user.person
      end

      def persist_created_agreement
        @safety_case.update!(status: 'restorative_in_progress')
        redirect_to_case('better_together.safety_agreements.notices.created', 'Restorative agreement created.')
      end

      def persist_updated_agreement
        @safety_case.update!(
          status: @safety_agreement.status_completed? ? 'resolved' : 'restorative_in_progress',
          resolved_at: @safety_agreement.status_completed? ? Time.current : @safety_case.resolved_at
        )
        redirect_to_case('better_together.safety_agreements.notices.updated', 'Restorative agreement updated.')
      end

      def render_case_show
        @safety_action = @safety_case.actions.new
        @safety_note = @safety_case.notes.new
        render 'better_together/safety/cases/show', status: :unprocessable_entity
      end

      def redirect_to_case(key, default_message)
        redirect_to safety_case_path(@safety_case, locale: I18n.locale),
                    notice: t(key, default: default_message)
      end

      def set_safety_case
        @safety_case = policy_scope(BetterTogether::Safety::Case).find(params[:safety_case_id])
      end

      def set_safety_agreement
        @safety_agreement = @safety_case.agreements.find(params[:id])
      end

      def safety_agreement_params
        params.require(:safety_agreement).permit(
          :status,
          :summary,
          :commitments,
          :harmed_party_consented,
          :responsible_party_consented,
          :review_at,
          :completed_at
        )
      end
    end
  end
end
