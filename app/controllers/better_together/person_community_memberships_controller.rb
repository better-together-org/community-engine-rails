# frozen_string_literal: true

module BetterTogether
  class PersonCommunityMembershipsController < ApplicationController
    before_action :set_community
    before_action :set_person_community_membership, only: [:destroy]
    after_action :verify_authorized

    # POST /communities/:community_id/person_community_memberships
    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @person_community_membership = @community.person_community_memberships.new(person_community_membership_params)
      authorize @person_community_membership

      respond_to do |format|
        if @person_community_membership.save
          flash[:notice] = 'Member was successfully added.'
          format.html { redirect_to @community, notice: flash[:notice] }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.append('members_list',
                                  # rubocop:todo Layout/LineLength
                                  partial: 'better_together/person_community_memberships/person_community_membership_member', locals: { membership: @person_community_membership }),
              # rubocop:enable Layout/LineLength
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                     locals: { flash: })
            ]
          end
        else
          flash.now[:alert] = 'Error adding member.'
          format.html { redirect_to @community, alert: @person_community_membership.errors.full_messages.to_sentence }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update('form_errors', partial: 'layouts/better_together/errors',
                                                 locals: { object: @person_community_membership }),
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                     locals: { flash: })
            ]
          end
        end
      end
    end

    def destroy # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @person_community_membership

      if @person_community_membership.destroy
        flash.now[:notice] = 'Member was successfully removed.'
        respond_to do |format|
          format.html { redirect_to @community }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(helpers.dom_id(@person_community_membership)),
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                     locals: { flash: })
            ]
          end
        end
      else
        flash.now[:error] = 'Failed to remove member.'
        respond_to do |format|
          format.html { redirect_to @community, alert: flash.now[:error] }
          format.turbo_stream do
            # rubocop:todo Layout/LineLength
            render turbo_stream: turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                                        # rubocop:enable Layout/LineLength
                                                                        locals: { flash: })
          end
        end
      end
    end

    private

    def set_community
      @community = ::BetterTogether::Community.find(params[:community_id])
    end

    def set_person_community_membership
      @person_community_membership = @community.person_community_memberships.find(params[:id])
    end

    def person_community_membership_params
      params.require(:person_community_membership).permit(:member_id, :role_id)
    end
  end
end
