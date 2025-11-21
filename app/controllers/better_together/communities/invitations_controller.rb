# frozen_string_literal: true

module BetterTogether
  module Communities
    class InvitationsController < ApplicationController # rubocop:todo Style/Documentation, Metrics/ClassLength
      before_action :set_community
      before_action :set_invitation, only: %i[destroy resend]
      after_action :verify_authorized, except: %i[available_people]
      after_action :verify_policy_scoped, only: %i[available_people]

      def create
        @invitation = build_invitation
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
          format.html { redirect_to @community, notice: t('flash.generic.destroyed', resource: t('resources.invitation')) }
          format.turbo_stream { render_destroy_turbo_stream(invitation_dom_id) }
          format.json { render json: { id: @invitation.id }, status: :ok }
        end
      end

      def resend
        authorize @invitation
        notify_invitee(@invitation)
        respond_success(@invitation, :ok)
      end

      def available_people
        invited_ids = invited_person_ids
        people = build_available_people_query(invited_ids)
        people = apply_search_filter(people) if params[:search].present?

        formatted_people = people.limit(20).map do |person|
          { value: person.id, text: person.name }
        end

        render json: formatted_people
      end

      private

      def set_community
        @community = BetterTogether::Community.friendly.find(params[:community_id])
      rescue StandardError
        render_not_found
      end

      def set_invitation
        @invitation = BetterTogether::CommunityInvitation.find(params[:id])
      end

      def invitation_params
        params.require(:invitation).permit(:invitee_id, :invitee_email, :valid_from, :valid_until, :locale, :role_id)
      end

      def build_invitation
        invitation = BetterTogether::CommunityInvitation.new(invitation_params)
        invitation.invitable = @community
        invitation.inviter = helpers.current_person
        invitation.status = 'pending'
        invitation.valid_from ||= Time.zone.now

        # Handle person invitation by ID
        setup_person_invitation(invitation) if params.dig(:invitation, :invitee_id).present?

        invitation
      end

      def setup_person_invitation(invitation)
        invitation.invitee = BetterTogether::Person.find(params[:invitation][:invitee_id])
        # Use the person's email address and locale
        invitation.invitee_email = invitation.invitee.email
        invitation.locale = invitation.invitee.locale || I18n.default_locale
      end

      def render_destroy_turbo_stream(invitation_dom_id)
        flash.now[:notice] = t('flash.generic.destroyed', resource: t('resources.invitation'))
        render turbo_stream: [
          turbo_stream.remove(invitation_dom_id),
          turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                 locals: { flash: })
        ]
      end

      def invited_person_ids
        # Get IDs of people who are already invited to this community
        BetterTogether::CommunityInvitation
          .where(invitable: @community, invitee_type: 'BetterTogether::Person')
          .pluck(:invitee_id)
      end

      def build_available_people_query(invited_ids)
        # Search for people excluding those already invited and those without email
        # Also exclude people who are already community members
        existing_member_ids = @community.person_community_memberships.pluck(:member_id)
        excluded_ids = (invited_ids + existing_member_ids).uniq

        policy_scope(BetterTogether::Person)
          .left_joins(:user, contact_detail: :email_addresses)
          .where.not(id: excluded_ids)
          .where(
            'better_together_users.email IS NOT NULL OR ' \
            'better_together_email_addresses.email IS NOT NULL'
          )
      end

      def apply_search_filter(people)
        search_term = "%#{params[:search]}%"
        people.joins(:string_translations)
              .where('mobility_string_translations.value ILIKE ? AND mobility_string_translations.key = ?',
                     search_term, 'name')
              .distinct
      end

      def recently_sent?(invitation)
        return false unless invitation.last_sent.present?

        if invitation.last_sent > 15.minutes.ago
          Rails.logger.info("Invitation #{invitation.id} recently sent; skipping resend")
          true
        else
          false
        end
      end

      def send_notification_to_user(invitation)
        # Send notification to existing user through the notification system
        BetterTogether::CommunityInvitationNotifier.with(record: invitation.invitable,
                                                         invitation:).deliver_later(invitation.invitee)
        invitation.update_column(:last_sent, Time.zone.now)
      end

      def send_email_invitation(invitation)
        # Send email directly to external email address (bypassing notification system)
        BetterTogether::CommunityInvitationsMailer.with(invitation:).invite.deliver_later
        invitation.update_column(:last_sent, Time.zone.now)
      end

      def render_success_turbo_stream(status)
        flash.now[:notice] = t('flash.generic.queued', resource: t('resources.invitation'))
        render turbo_stream: [
          turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                 locals: { flash: }),
          turbo_stream.replace('community_invitations_table_body',
                               partial: 'better_together/communities/invitation_row',
                               collection: @community.invitations.order(:status, :created_at))
        ], status:
      end

      def notify_invitee(invitation)
        # Simple throttling: skip if sent in last 15 minutes
        return if recently_sent?(invitation)

        if invitation.for_existing_user? && invitation.invitee.present?
          send_notification_to_user(invitation)
        elsif invitation.for_email?
          send_email_invitation(invitation)
        end
      end

      def respond_success(invitation, status)
        respond_to do |format|
          format.html { redirect_to @community, notice: t('flash.generic.queued', resource: t('resources.invitation')) }
          format.turbo_stream { render_success_turbo_stream(status) }
          format.json { render json: { id: invitation.id }, status: }
        end
      end

      def respond_error(invitation)
        respond_to do |format|
          format.html { redirect_to @community, alert: invitation.errors.full_messages.to_sentence }
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
