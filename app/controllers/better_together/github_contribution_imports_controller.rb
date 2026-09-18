# frozen_string_literal: true

module BetterTogether
  # Persists GitHub-native activity as governed contribution records on authorable content.
  class GithubContributionImportsController < ApplicationController
    CONTRIBUTABLE_TYPES = {
      'page' => BetterTogether::Page,
      'post' => BetterTogether::Post,
      'joatu_request' => BetterTogether::Joatu::Request,
      'joatu_offer' => BetterTogether::Joatu::Offer,
      'joatu_agreement' => BetterTogether::Joatu::Agreement
    }.freeze

    before_action :authenticate_user!
    before_action :set_contributable

    def create
      authorize @contributable, :update?

      render json: { contribution: contribution_payload(import_contribution) }
    end

    private

    def import_contribution
      BetterTogether::GithubContributionImportService.new(
        record: @contributable,
        contributor: current_user.person,
        source: import_source_params.to_h
      ).import!
    end

    def contribution_payload(contribution)
      {
        id: contribution.id,
        role: contribution.role,
        contribution_type: contribution.contribution_type,
        contributor_id: current_user.person.id,
        contributor_name: current_user.person.name,
        github_sources_count: Array(contribution.details['github_sources']).size
      }
    end

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
