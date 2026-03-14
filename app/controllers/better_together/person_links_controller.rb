# frozen_string_literal: true

module BetterTogether
  # Manages person-to-person platform link records for the current person.
  class PersonLinksController < ApplicationController
    before_action :set_person_link, only: %i[show revoke]

    def index
      authorize ::BetterTogether::PersonLink
      @person_links = policy_scope(::BetterTogether::PersonLink)
                      .includes(:source_person, :target_person,
                                platform_connection: %i[source_platform target_platform])
                      .order(updated_at: :desc, created_at: :desc)
    end

    def show
      authorize @person_link
      @person_access_grants = @person_link.person_access_grants.order(updated_at: :desc, created_at: :desc)
    end

    def revoke
      authorize @person_link, :revoke?

      @person_link.revoke!

      redirect_to person_link_path(@person_link),
                  notice: t('flash.generic.updated', resource: t('resources.agreement', default: 'person link')),
                  status: :see_other
    end

    private

    def set_person_link
      @person_link = policy_scope(::BetterTogether::PersonLink).find(params[:id])
    end
  end
end
