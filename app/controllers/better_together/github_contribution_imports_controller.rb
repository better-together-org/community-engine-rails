# frozen_string_literal: true

module BetterTogether
  # Persists GitHub-native activity as governed contribution records on authorable content.
  class GithubContributionImportsController < ApplicationController
    CONTRIBUTABLE_TYPES = {
      'page' => BetterTogether::Page,
      'post' => BetterTogether::Post
    }.freeze

    before_action :authenticate_user!
    before_action :set_contributable

    def create
      authorize @contributable, :update?

      contribution = BetterTogether::GithubContributionImportService.new(
        record: @contributable,
        contributor: current_user.person,
        source: import_source_params.to_h
      ).import!

      render json: {
        contribution: {
          id: contribution.id,
          role: contribution.role,
          contribution_type: contribution.contribution_type,
          contributor_id: current_user.person.id,
          contributor_name: current_user.person.name,
          github_sources_count: Array(contribution.details['github_sources']).size
        }
      }
    end

    private

    def set_contributable
      klass = CONTRIBUTABLE_TYPES[params[:contributable_key]]
      return render_not_found unless klass

      @contributable = klass.respond_to?(:friendly) ? klass.friendly.find(params[:id]) : klass.find(params[:id])
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
