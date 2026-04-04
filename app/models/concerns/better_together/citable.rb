# frozen_string_literal: true

module BetterTogether
  # Adds structured citations and bibliography helpers to a record.
  module Citable # rubocop:todo Metrics/ModuleLength
    extend ActiveSupport::Concern

    included do
      has_many :citations,
               -> { ordered },
               as: :citeable,
               class_name: 'BetterTogether::Citation',
               dependent: :destroy,
               inverse_of: :citeable

      accepts_nested_attributes_for :citations, allow_destroy: true, reject_if: :all_blank
    end

    class_methods do
      def extra_permitted_attributes # rubocop:todo Metrics/MethodLength
        super + [
          {
            citations_attributes: %i[
              id
              position
              reference_key
              source_kind
              title
              source_author
              publisher
              source_url
              locator
              published_on
              accessed_on
              excerpt
              rights_notes
              {
                metadata: {}
              }
              _destroy
            ]
          }
        ]
      end
    end

    def citation_for(reference_key)
      citations.find_by(reference_key: reference_key.to_s)
    end

    def bibliography_entries
      citations.ordered
    end

    def citation_reference_options
      bibliography_entries.map do |citation|
        [citation.reference_key, citation.title]
      end
    end

    def available_evidence_citation_sources
      sources = []

      if bibliography_entries.any?
        sources << ['Current record', bibliography_entries]
      end

      if respond_to?(:contributions)
        contributions.includes(:author, :citations).each do |contribution|
          next if contribution.bibliography_entries.blank?

          sources << [contribution_evidence_source_label(contribution), contribution.bibliography_entries]
        end
      end

      sources
    end

    def available_evidence_citation_option_groups
      available_evidence_citation_sources.each_with_object({}) do |(group_label, citations), groups|
        groups[group_label] = citations.map do |citation|
          ["#{citation.reference_key}: #{citation.title}", citation.id]
        end
      end
    end

    def available_evidence_citation_browser_groups # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      available_evidence_citation_sources.map do |group_label, citations|
        source_record = citations.first&.citeable
        {
          label: group_label,
          origin: evidence_browser_origin_for(source_record),
          record_type: evidence_browser_record_type_for(source_record),
          contribution_role: evidence_browser_contribution_role_for(source_record),
          contribution_type: evidence_browser_contribution_type_for(source_record),
          citations: citations.map do |citation|
            {
              id: citation.id,
              reference_key: citation.reference_key,
              title: citation.title,
              citeable_type: citation.citeable_type,
              citeable_id: citation.citeable_id,
              source_kind: citation.source_kind,
              source_author: citation.source_author,
              publisher: citation.publisher,
              locator: citation.locator,
              excerpt: citation.excerpt,
              source_url: citation.source_url
            }.compact
          end
        }
      end
    end

    def importable_linked_citation_groups
      available_evidence_citation_browser_groups.select { |group| group[:origin] == 'contribution' }
    end

    def imported_citation_count
      bibliography_entries.count(&:imported_from_linked_record?)
    end

    def citation_export_key
      {
        'BetterTogether::Page' => 'page',
        'BetterTogether::Post' => 'post',
        'BetterTogether::Event' => 'event',
        'BetterTogether::CallForInterest' => 'call_for_interest',
        'BetterTogether::Agreement' => 'agreement',
        'BetterTogether::Calendar' => 'calendar',
        'BetterTogether::Joatu::Request' => 'joatu_request',
        'BetterTogether::Joatu::Offer' => 'joatu_offer',
        'BetterTogether::Joatu::Agreement' => 'joatu_agreement'
      }[self.class.name]
    end

    def citations_as_csl_json(include_provenance: false)
      bibliography_entries.map { |citation| citation.to_csl_json(include_provenance:) }
    end

    def citation_export_lines(style, include_provenance: false)
      case style.to_s
      when 'apa'
        bibliography_entries.map { |citation| citation.apa_citation(include_provenance:) }
      when 'mla'
        bibliography_entries.map { |citation| citation.mla_citation(include_provenance:) }
      else
        []
      end
    end

    def governance_citation_bundle(include_provenance: false)
      {
        citeable: {
          type: self.class.name,
          id: id,
          label: to_s
        },
        summary: {
          citations: bibliography_entries.size,
          imported_citations: imported_citation_count,
          claims: respond_to?(:claims) ? claims.size : 0,
          contributions: respond_to?(:contributions) ? contributions.size : 0
        },
        citations: citations_as_csl_json(include_provenance:),
        claims: respond_to?(:claims_as_json_bundle) ? claims_as_json_bundle : [],
        contributions: governance_bundle_contributions
      }
    end

    private

    def contribution_evidence_source_label(contribution)
      contributor_name = contribution.author.respond_to?(:name) ? contribution.author.name : contribution.author.to_s
      contributor_name = 'Linked contributor' if contributor_name.blank?

      "#{contributor_name}: #{contribution.role.to_s.humanize}"
    end

    def evidence_browser_origin_for(source_record)
      source_record.is_a?(BetterTogether::Authorship) ? 'contribution' : 'current_record'
    end

    def evidence_browser_record_type_for(source_record)
      return self.class.model_name.human if source_record == self
      return source_record.class.model_name.human if source_record.respond_to?(:class) && source_record.class.respond_to?(:model_name)

      source_record.class.name.demodulize.humanize
    end

    def evidence_browser_contribution_role_for(source_record)
      source_record.respond_to?(:role) ? source_record.role.to_s : nil
    end

    def evidence_browser_contribution_type_for(source_record)
      source_record.respond_to?(:contribution_type) ? source_record.contribution_type.to_s : nil
    end

    def governance_bundle_contributions
      return [] unless respond_to?(:contributions)

      contributions.includes(:author).map do |contribution|
        contributor = contribution.author

        {
          id: contribution.id,
          role: contribution.role,
          contribution_type: contribution.contribution_type,
          contributor: {
            id: contributor&.id,
            type: contributor&.class&.name,
            name: contributor&.respond_to?(:name) ? contributor.name : contributor.to_s,
            github_handles: contributor&.respond_to?(:github_handles) ? contributor.github_handles : [],
            github_profile_urls: contributor&.respond_to?(:github_profile_urls) ? contributor.github_profile_urls : []
          }.compact
        }
      end
    end
  end
end
