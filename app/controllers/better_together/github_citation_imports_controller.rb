# frozen_string_literal: true

module BetterTogether
  # Returns importable GitHub citation candidates for the current person.
  class GithubCitationImportsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_citeable, only: :create

    def index
      return render json: { groups: [] } unless current_user&.person.present?

      render json: {
        groups: BetterTogether::GithubCitationImportCatalog.new(person: current_user.person).groups
      }
    end

    def create
      authorize @citeable, :update?

      citation = BetterTogether::GithubCitationImportService.new(
        record: @citeable,
        source: import_source_params.to_h
      ).import!

      render json: {
        citation: {
          id: citation.id,
          reference_key: citation.reference_key,
          title: citation.title,
          locator: citation.locator,
          excerpt: citation.excerpt
        }
      }
    end

    private

    CITEABLE_TYPES = BetterTogether::CitationExportsController::CITEABLE_TYPES

    def set_citeable
      klass = CITEABLE_TYPES[params[:citeable_key]]
      return render_not_found unless klass

      @citeable = klass.respond_to?(:friendly) ? klass.friendly.find(params[:id]) : klass.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_not_found
    end

    def import_source_params
      params.require(:source).permit(
        :reference_key,
        :source_kind,
        :title,
        :source_author,
        :publisher,
        :source_url,
        :locator,
        :excerpt,
        :published_on,
        :accessed_on,
        metadata: {}
      )
    end
  end
end
