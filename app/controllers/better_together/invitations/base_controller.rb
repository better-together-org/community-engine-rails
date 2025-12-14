# frozen_string_literal: true

module BetterTogether
  module Invitations
    # Base controller for invitation management across different invitable resources
    # Uses Template Method pattern to allow customization by subclasses
    class BaseController < ApplicationController # rubocop:todo Style/Documentation, Metrics/ClassLength
      before_action :set_invitable_resource
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
          format.html { redirect_to invitable_resource, notice: t('flash.generic.destroyed', resource: t('resources.invitation')) }
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

      # Template methods that subclasses must implement
      def invitation_class
        raise NotImplementedError, "#{self.class} must implement #invitation_class"
      end

      def invitable_resource
        raise NotImplementedError, "#{self.class} must implement #invitable_resource"
      end

      def mailer_class
        raise NotImplementedError, "#{self.class} must implement #mailer_class"
      end

      def notifier_class
        raise NotImplementedError, "#{self.class} must implement #notifier_class"
      end

      def table_body_id
        raise NotImplementedError, "#{self.class} must implement #table_body_id"
      end

      def invitation_row_partial
        raise NotImplementedError, "#{self.class} must implement #invitation_row_partial"
      end

      def generate_resend_path(invitation)
        raise NotImplementedError, "#{self.class} must implement #generate_resend_path"
      end

      def generate_destroy_path(invitation)
        raise NotImplementedError, "#{self.class} must implement #generate_destroy_path"
      end

      def set_invitable_resource
        raise NotImplementedError, "#{self.class} must implement #set_invitable_resource"
      end

      # Hook method with default implementation - override if needed
      def additional_exclusions(invited_ids)
        invited_ids
      end

      def set_invitation
        @invitation = invitation_class.find(params[:id])
      end

      def invitation_params
        params.require(:invitation).permit(:invitee_id, :invitee_email, :valid_from, :valid_until, :locale, :role_id)
      end

      def build_invitation
        invitation = create_base_invitation
        setup_person_invitation(invitation) if person_invitation_requested?
        invitation
      end

      def create_base_invitation
        invitation = invitation_class.new(invitation_params)
        invitation.invitable = invitable_resource
        invitation.inviter = helpers.current_person
        invitation.status = 'pending'
        invitation.valid_from ||= Time.zone.now
        invitation
      end

      def person_invitation_requested?
        params.dig(:invitation, :invitee_id).present?
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
        # Get IDs of people who are already invited to this resource
        invitation_class
          .where(invitable: invitable_resource, invitee_type: 'BetterTogether::Person')
          .pluck(:invitee_id)
      end

      def build_available_people_query(invited_ids)
        # Search for people excluding those already invited and those without email
        # Apply any additional exclusions (e.g., existing members)
        excluded_ids = additional_exclusions(invited_ids)

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
        notifier_class.with(record: invitation.invitable, invitation:).deliver_later(invitation.invitee)
        invitation.update_column(:last_sent, Time.zone.now)
      end

      def send_email_invitation(invitation)
        # Send email directly to external email address (bypassing notification system)
        mailer_class.with(invitation:).invite.deliver_later
        invitation.update_column(:last_sent, Time.zone.now)
      end

      def render_success_turbo_stream(status)
        flash.now[:notice] = t('flash.generic.queued', resource: t('resources.invitation'))

        # Build the invitation rows with proper parameters
        invitation_rows_html = invitable_resource.invitations.order(:status, :created_at).map do |invitation|
          render_to_string(
            partial: invitation_row_partial,
            formats: [:html], # Force HTML format to avoid turbo_stream format lookup
            locals: {
              invitation_row: invitation,
              resend_path: generate_resend_path(invitation),
              destroy_path: generate_destroy_path(invitation)
            }
          )
        end.join

        render turbo_stream: [
          turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                 locals: { flash: }),
          turbo_stream.update(table_body_id, invitation_rows_html)
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
          format.html { redirect_to invitable_resource, notice: t('flash.generic.queued', resource: t('resources.invitation')) }
          format.turbo_stream { render_success_turbo_stream(status) }
          format.json { render json: { id: invitation.id }, status: }
        end
      end

      def respond_error(invitation)
        respond_to do |format|
          format.html { redirect_to invitable_resource, alert: invitation.errors.full_messages.to_sentence }
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
