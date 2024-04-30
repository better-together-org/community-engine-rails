module BetterTogether
  class PersonCommunityMembershipsController < ApplicationController
    before_action :set_community
    before_action :set_person_community_membership, only: [:destroy]
    after_action :verify_authorized

    # POST /communities/:community_id/person_community_memberships
    def create
      @person_community_membership = @community.person_community_memberships.new(person_community_membership_params)
      authorize @person_community_membership

      respond_to do |format|
        if @person_community_membership.save
          flash[:notice] = 'Member was successfully added.'
          format.html { redirect_to @community, notice: flash[:notice] }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.append('members_list', partial: 'better_together/person_community_memberships/person_community_membership', locals: { person_community_membership: @person_community_membership }),
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages', locals: { flash: flash }),
            ]
          end
        else
          flash.now[:alert] = 'Error adding member.'
          format.html { redirect_to @community, alert: @person_community_membership.errors.full_messages.to_sentence }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update('form_errors', partial: 'layouts/better_together/errors', locals: { object: @person_community_membership }),
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages', locals: { flash: flash })
            ]
          end
        end
      end
    end

    def destroy
      authorize @person_community_membership
    
      if @person_community_membership.destroy
        flash.now[:notice] = 'Member was successfully removed.'
        respond_to do |format|
          format.html { redirect_to @community }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(helpers.dom_id(@person_community_membership)),
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages', locals: { flash: flash })
            ]
          end
        end
      else
        flash.now[:error] = 'Failed to remove member.'
        respond_to do |format|
          format.html { redirect_to @community, alert: flash.now[:error] }
          format.turbo_stream { render turbo_stream: turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages', locals: { flash: flash }) }
        end
      end
    end
    


    private

    def set_community
      @community = ::BetterTogether::Community.friendly.find(params[:community_id])
    end

    def set_person_community_membership
      @person_community_membership = @community.person_community_memberships.find(params[:id])
    end

    def person_community_membership_params
      params.require(:person_community_membership).permit(:member_id, :role_id)
    end
  end
end
