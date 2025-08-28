# frozen_string_literal: true

module BetterTogether
  class InvitationsController < ApplicationController
    skip_before_action :authenticate_user!
    before_action :find_invitation_by_token

    def show
      @event = @invitation.invitable if @invitation.is_a?(BetterTogether::EventInvitation)
      render :show
    end

    def accept
      ensure_authenticated!
      return if performed?

      person = helpers.current_person
      if @invitation.invitee.present? && @invitation.invitee != person
        redirect_to new_user_session_path(locale: I18n.locale), alert: t('flash.generic.unauthorized') and return
      end

      @invitation.update!(invitee: person) if @invitation.invitee.blank?
      if @invitation.respond_to?(:accept!)
        # EventInvitation implements accept!(invitee_person:)
        @invitation.accept!(invitee_person: person)
      else
        @invitation.update!(status: 'accepted')
      end

      redirect_to polymorphic_path(@invitation.invitable), notice: t('flash.generic.updated', resource: t('resources.invitation'))
    end

    def decline
      ensure_authenticated!
      return if performed?

      if @invitation.respond_to?(:decline!)
        @invitation.decline!
      else
        @invitation.update!(status: 'declined')
      end
      redirect_to root_path(locale: I18n.locale), notice: t('flash.generic.updated', resource: t('resources.invitation'))
    end

    private

    def find_invitation_by_token
      token = params[:token].to_s
      @invitation = BetterTogether::Invitation.pending.not_expired.find_by(token: token)
      render_not_found unless @invitation
    end

    def ensure_authenticated!
      return if helpers.current_person.present?

      redirect_to new_user_session_path(locale: I18n.locale), alert: t('flash.generic.unauthorized')
    end
  end
end
