# frozen_string_literal: true

module BetterTogether
  class PlatformInvitationsController < ApplicationController # rubocop:todo Style/Documentation
    before_action :set_platform
    before_action :set_platform_invitation, only: %i[destroy resend]
    after_action :verify_authorized

    # POST /platforms/:platform_id/platform_invitations
    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @platform_invitation = @platform.invitations.new(platform_invitation_params) do |pi|
        pi.invitable = @platform
        pi.inviter = helpers.current_person
        pi.valid_from = Time.zone.now
        pi.status = 'pending'
        pi.locale = I18n.locale unless pi.locale
      end

      authorize @platform_invitation

      respond_to do |format|
        if @platform_invitation.save
          flash[:notice] = 'Invitation was successfully created.'
          format.html { redirect_to @platform, notice: flash[:notice] }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend('platform_invitations_table_body',
                                   # rubocop:todo Layout/LineLength
                                   partial: 'better_together/platform_invitations/platform_invitation', locals: { platform_invitation: @platform_invitation }),
              # rubocop:enable Layout/LineLength
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                     locals: { flash: })
            ]
          end
        else
          flash.now[:alert] = 'Error creating platform_invitation.'
          format.html { redirect_to @platform, alert: @platform_invitation.errors.full_messages.to_sentence }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update('form_errors', partial: 'layouts/better_together/errors',
                                                 locals: { object: @platform_invitation }),
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                     locals: { flash: })
            ]
          end
        end
      end
    end

    def destroy # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @platform_invitation

      if @platform_invitation.destroy
        flash.now[:notice] = 'Invitation was successfully removed.'
        respond_to do |format|
          format.html { redirect_to @platform }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(helpers.dom_id(@platform_invitation)),
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                     locals: { flash: })
            ]
          end
        end
      else
        flash.now[:error] = 'Failed to remove platform_invitation.'
        respond_to do |format|
          format.html { redirect_to @platform, alert: flash.now[:error] }
          format.turbo_stream do
            # rubocop:todo Layout/LineLength
            render turbo_stream: turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                                        # rubocop:enable Layout/LineLength
                                                                        locals: { flash: })
          end
        end
      end
    end

    # PUT /platforms/:platform_id/platform_invitations/:id/resend
    def resend # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @platform_invitation

      BetterTogether::PlatformInvitationMailerJob.perform_later(@platform_invitation.id)
      flash[:notice] = 'Invitation email has been queued for sending.'

      respond_to do |format|
        format.html { redirect_to @platform, notice: flash[:notice] }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@platform_invitation),
                                 partial: 'better_together/platform_invitations/platform_invitation',
                                 locals: { platform_invitation: @platform_invitation }),
            turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                   locals: { flash: })
          ]
        end
      end
    end

    private

    def set_platform
      @platform = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(
        translatable_type: 'BetterTogether::Platform',
        key: 'slug',
        value: params[:platform_id],
        locale: I18n.available_locales
      ).includes(:translatable).last&.translatable
    end

    def set_platform_invitation
      @platform_invitation = @platform.invitations.find(params[:id])
    end

    def platform_invitation_params
      params.require(:platform_invitation).permit(:invitee_email, :platform_role_id, :community_role_id, :locale)
    end
  end
end
