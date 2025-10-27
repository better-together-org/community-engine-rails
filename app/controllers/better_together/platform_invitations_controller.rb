# frozen_string_literal: true

module BetterTogether
  # rubocop:todo Metrics/ClassLength
  class PlatformInvitationsController < ApplicationController # rubocop:todo Style/Documentation
    before_action :set_platform
    before_action :set_platform_invitation, only: %i[destroy resend]
    after_action :verify_authorized

    before_action only: %i[index], if: -> { Rails.env.development? } do
      # Make sure that all Platform Invitation subclasses are loaded in dev to generate new block buttons
      ::BetterTogether::PlatformInvitation.load_all_subclasses
    end

    # GET /platforms/:platform_id/platform_invitations
    def index
      authorize BetterTogether::PlatformInvitation

      # Use optimized query with all necessary includes to prevent N+1
      @platform_invitations = policy_scope(@platform.invitations)
                              .includes(
                                { inviter: [:string_translations] },
                                { invitee: [:string_translations] }
                              )

      # Preload roles for the form to prevent N+1 queries during rendering
      @community_roles = BetterTogether::Role.where(resource_type: 'BetterTogether::Community')
                                             .includes(:string_translations)
                                             .order(:position)
      @platform_roles = BetterTogether::Role.where(resource_type: 'BetterTogether::Platform')
                                            .includes(:string_translations)
                                            .order(:position)

      # Find the default community member role for the hidden field
      @default_community_role = @community_roles.find_by(identifier: 'community_member')
    end

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
          flash[:notice] = t('flash.generic.created', resource: t('resources.invitation'))
          format.html { redirect_to @platform, notice: flash[:notice] }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend('platform_invitations_table_body',
                                   partial: 'better_together/platform_invitations/platform_invitation',
                                   locals: { platform_invitation: @platform_invitation }),
              turbo_stream.replace('flash_messages',
                                   partial: 'layouts/better_together/flash_messages',
                                   locals: { flash: })
            ]
          end
        else
          flash.now[:alert] = t('flash.generic.error_create', resource: t('resources.invitation'))
          format.html do
            redirect_to platform_platform_invitations_path(@platform),
                        alert: @platform_invitation.errors.full_messages.to_sentence
          end
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update('form_errors',
                                  partial: 'layouts/better_together/errors',
                                  locals: { object: @platform_invitation }),
              turbo_stream.replace('flash_messages',
                                   partial: 'layouts/better_together/flash_messages',
                                   locals: { flash: })
            ]
          end
        end
      end
    end

    def destroy # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @platform_invitation

      if @platform_invitation.destroy
        flash.now[:notice] = t('flash.generic.removed', resource: t('resources.invitation'))
        respond_to do |format|
          format.html { redirect_to platform_platform_invitations_path(@platform) }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(helpers.dom_id(@platform_invitation)),
              turbo_stream.replace('flash_messages',
                                   partial: 'layouts/better_together/flash_messages',
                                   locals: { flash: })
            ]
          end
        end
      else
        flash.now[:error] = t('flash.generic.error_remove', resource: t('resources.invitation'))
        respond_to do |format|
          format.html { redirect_to platform_platform_invitations_path(@platform), alert: flash.now[:error] }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace('flash_messages',
                                                      partial: 'layouts/better_together/flash_messages',
                                                      locals: { flash: })
          end
        end
      end
    end

    # PUT /platforms/:platform_id/platform_invitations/:id/resend
    def resend # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @platform_invitation

      BetterTogether::PlatformInvitationMailerJob.perform_later(@platform_invitation.id)
      flash[:notice] = t('flash.generic.queued', resource: t('resources.invitation_email'))

      respond_to do |format|
        format.html { redirect_to platform_platform_invitations_path(@platform), notice: flash[:notice] }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@platform_invitation),
                                 partial: 'better_together/platform_invitations/platform_invitation',
                                 locals: { platform_invitation: @platform_invitation }),
            turbo_stream.replace('flash_messages',
                                 partial: 'layouts/better_together/flash_messages',
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
      params.require(:platform_invitation).permit(
        :invitee_email, :platform_role_id, :community_role_id, :locale,
        :valid_from, :valid_until, :greeting, :type, :session_duration_mins,
        *param_invitation_class.permitted_attributes
      )
    end

    def param_invitation_class
      param_type = params[:platform_invitation][:type]

      Rails.application.eager_load! unless Rails.env.production? # Ensure all models are loaded
      valid_types = [BetterTogether::PlatformInvitation, *BetterTogether::PlatformInvitation.descendants]
      valid_types.find { |klass| klass.to_s == param_type }
    end
  end
  # rubocop:enable Metrics/ClassLength
end
