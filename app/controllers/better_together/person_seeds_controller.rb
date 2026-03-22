# frozen_string_literal: true

module BetterTogether
  # Person-scoped seed management for GDPR self-service data access (view, export, delete)
  class PersonSeedsController < ApplicationController
    before_action :set_seed, only: %i[show destroy]

    # GET /my/seeds
    def index
      authorize Seed, policy_class: PersonSeedPolicy
      @seeds = PersonSeedPolicy::Scope.new(current_user, Seed).resolve
                                      .page(params[:page]).per(25)
    end

    # GET /my/seeds/:id
    def show
      authorize @seed, policy_class: PersonSeedPolicy
    end

    # POST /my/seeds/export
    def export # rubocop:todo Metrics/AbcSize
      authorize Seed, policy_class: PersonSeedPolicy

      person = current_user.person
      # authorize above confirms agent is present, but guard explicitly so
      # calling .export_as_seed on nil is impossible even if policy changes
      return redirect_to person_seeds_path, alert: t('person_seeds.export_unavailable') unless person

      if Seed.where(creator_id: person.id).where(created_at: 1.hour.ago..).exists?
        return redirect_to person_seeds_path, alert: t('person_seeds.export_too_soon')
      end

      begin
        person.export_as_seed(creator_id: person.id)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "[GDPR] Export failed for person #{person.id}: #{e.message}"
        return redirect_to person_seeds_path, alert: t('person_seeds.export_failed')
      end

      Rails.logger.info "[GDPR] Personal data export requested by person #{person.id}"
      redirect_to person_seeds_path, notice: t('person_seeds.export_queued')
    end

    # DELETE /my/seeds/:id
    def destroy
      authorize @seed, policy_class: PersonSeedPolicy
      identifier = @seed.identifier
      @seed.destroy!
      Rails.logger.info "[GDPR] Seed '#{identifier}' (#{@seed.id}) deleted by person #{current_user.person&.id}"
      redirect_to person_seeds_path,
                  notice: t('flash.generic.destroyed', resource: t('resources.seed')),
                  status: :see_other
    end

    private

    # Scope the find through the policy scope so the ownership SQL lives in
    # exactly one place (PersonSeedPolicy::Scope). Any seed ID not belonging
    # to this person raises RecordNotFound (404) before Pundit even runs.
    def set_seed
      person = current_user.person
      raise ActiveRecord::RecordNotFound unless person

      @seed = PersonSeedPolicy::Scope.new(current_user, Seed).resolve.find(params[:id])
    end
  end
end
