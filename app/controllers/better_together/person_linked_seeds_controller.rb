# frozen_string_literal: true

module BetterTogether
  # Manages linked seed records synchronized to the current person.
  class PersonLinkedSeedsController < ApplicationController
    before_action :set_person_linked_seed, only: :show

    def index
      authorize ::BetterTogether::PersonLinkedSeed
      @person_linked_seeds = policy_scope(::BetterTogether::PersonLinkedSeed)
                             .includes(:source_platform, :person_access_grant)
                             .order(last_synced_at: :desc, created_at: :desc)
    end

    def show
      authorize @person_linked_seed
      @payload_data = @person_linked_seed.payload_data
    end

    private

    def set_person_linked_seed
      @person_linked_seed = policy_scope(::BetterTogether::PersonLinkedSeed).find(params[:id])
    end
  end
end
