# frozen_string_literal: true

module BetterTogether
  # Allows for CRUD operations for Person Platform Memberships
  class PersonPlatformMembershipsController < ApplicationController
    before_action :set_platform
    before_action :set_person_platform_membership, only: %i[show edit update destroy]
    before_action :authorize_person_platform_membership, only: %i[show edit update destroy]

    # POST /platforms/:platform_id/person_platform_memberships
    def create # rubocop:todo Metrics/MethodLength
      @person_platform_membership = PersonPlatformMembership.new(
        person_platform_membership_params.merge(joinable_id: @platform.id)
      )
      authorize @person_platform_membership

      respond_to do |format|
        if @person_platform_membership.save
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              'platform_members_list',
              partial: 'better_together/person_platform_memberships/members_list',
              locals: { platform: @platform, memberships: @platform.memberships_with_associations }
            )
          end
          format.html do
            redirect_to @platform, notice: t('flash.generic.created',
                                             resource: t('resources.person_platform_membership'))
          end
        else
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @person_platform_membership }
            )
          end
          format.html { render :new, status: :unprocessable_content }
        end
      end
    end

    # DELETE /platforms/:platform_id/person_platform_memberships/:id
    def destroy # rubocop:todo Metrics/MethodLength
      authorize @person_platform_membership

      if @person_platform_membership.destroy
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(helpers.dom_id(@person_platform_membership)),
              turbo_stream.update(
                'flash_messages',
                partial: 'layouts/better_together/flash_messages',
                locals: { flash: { notice: t('flash.generic.destroyed',
                                             resource: t('resources.person_platform_membership')) } }
              )
            ]
          end
          format.html do
            redirect_to @platform,
                        notice: t('flash.generic.destroyed', resource: t('resources.person_platform_membership')),
                        status: :see_other
          end
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'flash_messages',
              partial: 'layouts/better_together/flash_messages',
              locals: { flash: { alert: @person_platform_membership.errors.full_messages.to_sentence } }
            )
          end
          format.html do
            redirect_to @platform,
                        alert: @person_platform_membership.errors.full_messages.to_sentence,
                        status: :unprocessable_content
          end
        end
      end
    end

    private

    # Set the platform for scoped operations
    def set_platform
      @platform = ::BetterTogether::Platform.friendly.find(params[:platform_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_person_platform_membership
      @person_platform_membership = PersonPlatformMembership.find(params[:id])
      raise ActiveRecord::RecordNotFound unless @person_platform_membership.joinable_id == @platform.id
    end

    # Only allow a list of trusted parameters through.
    def person_platform_membership_params
      params.require(:person_platform_membership).permit(:member_id, :role_id, :joinable_id)
    end

    # Adds a policy check for the person platform membership
    def authorize_person_platform_membership
      authorize @person_platform_membership
    end
  end
end
