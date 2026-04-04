# frozen_string_literal: true

module BetterTogether
  # Returns importable GitHub citation candidates for the current person.
  class GithubCitationImportsController < ApplicationController
    before_action :authenticate_user!

    def index
      return render json: { groups: [] } unless current_user&.person.present?

      render json: {
        groups: BetterTogether::GithubCitationImportCatalog.new(person: current_user.person).groups
      }
    end
  end
end
