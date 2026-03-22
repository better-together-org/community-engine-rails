# frozen_string_literal: true

module BetterTogether
  module Safety
    # Creates notes for a safety case.
    class NotesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_safety_case
      after_action :verify_authorized

      def create
        build_safety_note
        authorize @safety_note

        return redirect_to_case if @safety_note.save

        render_case_show
      end

      private

      def build_safety_note
        @safety_note = @safety_case.notes.new(safety_note_params)
        @safety_note.author = current_user.person
      end

      def redirect_to_case
        redirect_to safety_case_path(@safety_case, locale: I18n.locale),
                    notice: t('better_together.safety_notes.notices.created', default: 'Case note added.')
      end

      def render_case_show
        @safety_action = @safety_case.actions.new
        @safety_agreement = @safety_case.agreements.new
        render 'better_together/safety/cases/show', status: :unprocessable_entity
      end

      def set_safety_case
        @safety_case = policy_scope(BetterTogether::Safety::Case).find(params[:safety_case_id])
      end

      def safety_note_params
        params.require(:safety_note).permit(:visibility, :body)
      end
    end
  end
end
