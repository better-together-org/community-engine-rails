# frozen_string_literal: true

module BetterTogether
  class PersonCommunityMembershipsController < ApplicationController # rubocop:todo Style/Documentation, Metrics/ClassLength
    before_action :set_community
    before_action :set_person_community_membership, only: [:destroy]
    after_action :verify_authorized

    # POST /communities/:community_id/person_community_memberships
    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @person_community_membership = build_person_community_membership
      authorize @person_community_membership

      # rubocop:todo Metrics/BlockLength
      respond_to do |format|
        if self_service_request? && @person_community_membership.persisted?
          flash[:notice] = existing_self_service_notice(@person_community_membership)
          format.html { redirect_to @community, notice: flash[:notice] }
        elsif @person_community_membership.save
          flash[:notice] = membership_created_notice(@person_community_membership)
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
          flash.now[:alert] = t('flash.generic.error_create', resource: t('resources.member'))
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
      # rubocop:enable Metrics/BlockLength
    end

    def destroy # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @person_community_membership

      if @person_community_membership.destroy
        flash.now[:notice] = t('flash.generic.removed', resource: t('resources.member'))
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
        flash.now[:error] = t('flash.generic.error_remove', resource: t('resources.member'))
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

    def build_person_community_membership
      return build_self_service_membership if self_service_request?

      @community.person_community_memberships.new(person_community_membership_params.merge(status: 'active'))
    end

    def build_self_service_membership
      membership = current_person_membership_for_self_service
      assign_self_service_defaults(membership)
      membership
    end

    def self_service_request?
      params.dig(:person_community_membership, :self_service) == '1'
    end

    def membership_created_notice(membership)
      if self_service_request? && membership.pending?
        return t('better_together.access_modes.membership_requested',
                 default: 'Your membership request was submitted.')
      end

      if self_service_request? && membership.active?
        return t('better_together.access_modes.membership_joined',
                 default: 'You joined this community.')
      end

      t('flash.generic.created', resource: t('resources.member'))
    end

    def existing_self_service_notice(membership)
      if membership.pending?
        return t('better_together.access_modes.membership_request_pending',
                 default: 'Your membership request is already pending.')
      end

      t('better_together.access_modes.already_member',
        default: 'You are already a member of this community.')
    end

    def current_person_membership_for_self_service
      return @community.person_community_memberships.new unless helpers.current_person.present?

      @community.person_community_memberships.find_or_initialize_by(member: helpers.current_person)
    end

    def assign_self_service_defaults(membership)
      membership.member ||= helpers.current_person
      membership.role ||= @community.default_member_role
      membership.status = @community.self_service_membership_status if membership.new_record?
      membership.errors.add(:role, :blank) unless membership.role.present?
    end
  end
end
