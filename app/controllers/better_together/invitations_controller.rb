# frozen_string_literal: true

module BetterTogether
  class InvitationsController < ApplicationController # rubocop:todo Style/Documentation
    # skip_before_action :authenticate_user!
    prepend_before_action :find_invitation_by_token
    skip_before_action :check_platform_privacy, if: -> { @invitation.present? }

    def show
      @event = @invitation.invitable if @invitation.is_a?(BetterTogether::EventInvitation)
      render :show
    end

    def accept
      ensure_authenticated!
      return if performed?

      person = helpers.current_person
      return unless authorize_invitee(person)

      process_invitation_acceptance(person)
      redirect_to polymorphic_path(@invitation.invitable),
                  notice: t('flash.generic.updated', resource: t('resources.invitation'))
    end

    def decline
      # ensure_authenticated!
      return if performed?

      process_invitation_decline
      redirect_to determine_decline_redirect_path,
                  notice: t('flash.generic.updated', resource: t('resources.invitation'))
    end

    private

    def find_invitation_by_token
      token = params[:invitation_token].presence || params[:token].presence
      @invitation = BetterTogether::Invitation.pending.not_expired.find_by(token: token)
      render_not_found unless @invitation
    end

    def ensure_authenticated!
      return if current_user

      store_invitation_in_session
      redirect_to determine_auth_redirect_path, notice: determine_auth_notice
    end

    def store_invitation_in_session
      # Store invitation token in session for after authentication
      return unless @invitation.is_a?(BetterTogether::EventInvitation)

      session[:event_invitation_token] = @invitation.token
      session[:event_invitation_expires_at] = 24.hours.from_now
    end

    def determine_auth_redirect_path
      if BetterTogether::User.find_by(email: @invitation.invitee_email).present?
        new_user_session_path(locale: I18n.locale)
      else
        new_user_registration_path(locale: I18n.locale)
      end
    end

    def determine_auth_notice
      if BetterTogether::User.find_by(email: @invitation.invitee_email).present?
        t('better_together.invitations.login_to_respond',
          default: 'Please log in to respond to your invitation.')
      else
        t('better_together.invitations.register_to_respond',
          default: 'Please register to respond to your invitation.')
      end
    end

    def authorize_invitee(person)
      if @invitation.invitee.present? && @invitation.invitee != person
        redirect_to new_user_session_path(locale: I18n.locale), alert: t('flash.generic.unauthorized')
        false
      else
        true
      end
    end

    def process_invitation_acceptance(person)
      @invitation.update!(invitee: person) if @invitation.invitee.blank?
      if @invitation.respond_to?(:accept!)
        # EventInvitation implements accept!(invitee_person:)
        @invitation.accept!(invitee_person: person)
      else
        @invitation.update!(status: 'accepted')
      end
    end

    def process_invitation_decline
      if @invitation.respond_to?(:decline!)
        @invitation.decline!
      else
        @invitation.update!(status: 'declined')
      end
    end

    def determine_decline_redirect_path
      # For event invitations, redirect to the event. Otherwise use root path.
      if @invitation.respond_to?(:event) && @invitation.event
        polymorphic_path(@invitation.invitable)
      else
        root_path(locale: I18n.locale)
      end
    end
  end
end
