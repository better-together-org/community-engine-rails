# frozen_string_literal: true

module BetterTogether
  class PersonAccessGrantsController < ApplicationController
    before_action :set_person_access_grant, only: %i[show update revoke]

    def index
      authorize ::BetterTogether::PersonAccessGrant
      @person_access_grants = policy_scope(::BetterTogether::PersonAccessGrant)
                              .includes(:grantor_person, :grantee_person, :person_link)
                              .order(updated_at: :desc, created_at: :desc)
    end

    def show
      authorize @person_access_grant
    end

    def update
      authorize @person_access_grant

      if @person_access_grant.update(person_access_grant_params)
        redirect_to person_access_grant_path(@person_access_grant),
                    notice: t('flash.generic.updated', resource: t('resources.agreement', default: 'access grant')),
                    status: :see_other
      else
        render :show, status: :unprocessable_content
      end
    end

    def revoke
      authorize @person_access_grant, :revoke?

      @person_access_grant.revoke!

      redirect_to person_access_grant_path(@person_access_grant),
                  notice: t('flash.generic.updated', resource: t('resources.agreement', default: 'access grant')),
                  status: :see_other
    end

    private

    def set_person_access_grant
      @person_access_grant = policy_scope(::BetterTogether::PersonAccessGrant).find(params[:id])
    end

    def person_access_grant_params
      params.require(:person_access_grant).permit(
        :allow_profile_read,
        :allow_private_posts,
        :allow_private_pages,
        :allow_private_events,
        :allow_private_messages,
        :expires_at
      )
    end
  end
end
