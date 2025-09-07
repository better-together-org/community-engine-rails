# frozen_string_literal: true

module BetterTogether
  module Events
    class InvitationsController < ApplicationController # rubocop:todo Style/Documentation
      before_action :set_event
      before_action :set_invitation, only: %i[destroy resend]
      after_action :verify_authorized, except: %i[available_people]
      after_action :verify_policy_scoped, only: %i[available_people]

      def create # rubocop:todo Metrics/MethodLength
        @invitation = BetterTogether::EventInvitation.new(invitation_params)
        @invitation.invitable = @event
        @invitation.inviter = helpers.current_person
        @invitation.status = 'pending'
        @invitation.valid_from ||= Time.zone.now

        # Handle person invitation by ID
        if params.dig(:invitation, :invitee_id).present?
          @invitation.invitee = BetterTogether::Person.find(params[:invitation][:invitee_id])
          # Use the person's email address and locale
          @invitation.invitee_email = @invitation.invitee.email
          @invitation.locale = @invitation.invitee.locale || I18n.default_locale
        end

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
        invitation_dom_id = helpers.dom_id(@invitation)
        @invitation.destroy

        respond_to do |format|
          format.html { redirect_to @event, notice: t('flash.generic.destroyed', resource: t('resources.invitation')) }
          format.turbo_stream do
            flash.now[:notice] = t('flash.generic.destroyed', resource: t('resources.invitation'))
            render turbo_stream: [
              turbo_stream.remove(invitation_dom_id),
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                     locals: { flash: })
            ]
          end
          format.json { render json: { id: @invitation.id }, status: :ok }
        end
      end

      def resend
        authorize @invitation
        notify_invitee(@invitation)
        respond_success(@invitation, :ok)
      end

      def available_people
        # Get IDs of people who are already invited to this event
        # We use EventInvitation directly to avoid the default scope with includes(:invitee)
        invited_person_ids = BetterTogether::EventInvitation
                             .where(invitable: @event, invitee_type: 'BetterTogether::Person')
                             .pluck(:invitee_id)

        # Search for people excluding those already invited and those without email
        # People have email through either user.email or contact_detail.email_addresses (association)
        people = policy_scope(BetterTogether::Person)
                 .left_joins(:user, contact_detail: :email_addresses)
                 .where.not(id: invited_person_ids)
                 .where(
                   'better_together_users.email IS NOT NULL OR ' \
                   'better_together_email_addresses.email IS NOT NULL'
                 )

        # Apply search filter if provided
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          people = people.joins(:string_translations)
                         .where('mobility_string_translations.value ILIKE ? AND mobility_string_translations.key = ?',
                                search_term, 'name')
                         .distinct
        end

        # Format for SlimSelect
        formatted_people = people.limit(20).map do |person|
          { value: person.id, text: person.name }
        end

        render json: formatted_people
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
        params.require(:invitation).permit(:invitee_id, :invitee_email, :valid_from, :valid_until, :locale, :role_id)
      end

      def notify_invitee(invitation) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # Simple throttling: skip if sent in last 15 minutes
        if invitation.last_sent.present? && invitation.last_sent > 15.minutes.ago
          Rails.logger.info("Invitation #{invitation.id} recently sent; skipping resend")
          return
        end

        if invitation.for_existing_user? && invitation.invitee.present?
          # Send notification to existing user through the notification system
          BetterTogether::EventInvitationNotifier.with(record: invitation.invitable,
                                                       invitation:).deliver_later(invitation.invitee)
          invitation.update_column(:last_sent, Time.zone.now)
        elsif invitation.for_email?
          # Send email directly to external email address (bypassing notification system)
          BetterTogether::EventInvitationsMailer.invite(invitation).deliver_later
          invitation.update_column(:last_sent, Time.zone.now)
        end
      end

      def respond_success(invitation, status) # rubocop:todo Metrics/MethodLength
        respond_to do |format|
          format.html { redirect_to @event, notice: t('flash.generic.queued', resource: t('resources.invitation')) }
          format.turbo_stream do
            flash.now[:notice] = t('flash.generic.queued', resource: t('resources.invitation'))
            render turbo_stream: [
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                     locals: { flash: }),
              turbo_stream.replace('event_invitations_table_body',
                                   partial: 'better_together/events/invitation_row',
                                   collection: @event.invitations.order(:status, :created_at))
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
