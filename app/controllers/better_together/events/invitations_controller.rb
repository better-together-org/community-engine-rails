# frozen_string_literal: true

module BetterTogether
  module Events
    class InvitationsController < ApplicationController # rubocop:todo Style/Documentation
      before_action :set_event
      before_action :set_invitation, only: %i[destroy resend]
      after_action :verify_authorized

      def create # rubocop:todo Metrics/MethodLength
        @invitation = BetterTogether::EventInvitation.new(invitation_params)
        @invitation.invitable = @event
        @invitation.inviter = helpers.current_person
        @invitation.status = 'pending'
        @invitation.valid_from ||= Time.zone.now

        authorize @invitation

        if @invitation.save
          notify_invitee(@invitation)
          respond_success(@invitation, :created)
        else
          respond_error(@invitation)
        end
      end

      def destroy
        authorize @invitation
        @invitation.destroy
        respond_success(@invitation, :ok)
      end

      def resend
        authorize @invitation
        notify_invitee(@invitation)
        respond_success(@invitation, :ok)
      end

      private

      def set_event
        @event = BetterTogether::Event.friendly.find(params[:event_id])
      rescue StandardError
        render_not_found
      end

      def set_invitation
        @invitation = BetterTogether::EventInvitation.find(params[:id])
      end

      def invitation_params
        params.require(:invitation).permit(:invitee_email, :valid_from, :valid_until, :locale, :role_id)
      end

      def notify_invitee(invitation) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # Simple throttling: skip if sent in last 15 minutes
        if invitation.last_sent.present? && invitation.last_sent > 15.minutes.ago
          Rails.logger.info("Invitation #{invitation.id} recently sent; skipping resend")
          return
        end

        if invitation.invitee.present?
          BetterTogether::EventInvitationNotifier.with(invitation:).deliver_later(invitation.invitee)
          invitation.update_column(:last_sent, Time.zone.now)
        elsif invitation.respond_to?(:invitee_email) && invitation[:invitee_email].present?
          BetterTogether::EventInvitationsMailer.invite(invitation).deliver_later
          invitation.update_column(:last_sent, Time.zone.now)
        end
      end

      def respond_success(invitation, status) # rubocop:todo Metrics/MethodLength
        respond_to do |format|
          format.html { redirect_to @event, notice: t('flash.generic.queued', resource: t('resources.invitation')) }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                     locals: { flash: }),
              turbo_stream.replace('event_invitations_table_body',
                                   partial: 'better_together/events/pending_invitation_rows', locals: { event: @event })
            ], status:
          end
          format.json { render json: { id: invitation.id }, status: }
        end
      end

      def respond_error(invitation)
        respond_to do |format|
          format.html { redirect_to @event, alert: invitation.errors.full_messages.to_sentence }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update('form_errors', partial: 'layouts/better_together/errors', locals: { object: invitation }) # rubocop:disable Layout/LineLength
            ], status: :unprocessable_entity
          end
          format.json { render json: { errors: invitation.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end
  end
end
