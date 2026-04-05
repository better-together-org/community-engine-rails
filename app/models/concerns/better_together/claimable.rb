# frozen_string_literal: true

module BetterTogether
  # Adds claim and evidence link support to published and contributed records.
  module Claimable # rubocop:todo Metrics/ModuleLength
    extend ActiveSupport::Concern

    RICH_TEXT_SELECTOR_ATTRIBUTES = %w[content description description_html].freeze

    included do
      has_many :claims,
               -> { order(:position, :created_at) },
               as: :claimable,
               class_name: 'BetterTogether::Claim',
               dependent: :destroy,
               inverse_of: :claimable

      accepts_nested_attributes_for :claims, allow_destroy: true, reject_if: :reject_blank_claim_attributes?
    end

    class_methods do # rubocop:todo Metrics/BlockLength
      def extra_permitted_attributes # rubocop:todo Metrics/MethodLength
        super + [
          {
            claims_attributes: [
              :id,
              :position,
              :claim_key,
              :statement,
              :selector,
              :review_status,
              :_destroy,
              {
                evidence_links_attributes: %i[
                  id
                  position
                  citation_id
                  relation_type
                  locator
                  quoted_text
                  editor_note
                  review_status
                  _destroy
                ]
              }
            ]
          }
        ]
      end
    end

    private

    def reject_blank_claim_attributes?(attributes)
      claim_attributes = attributes.except('evidence_links_attributes', 'review_status')
      return false unless claim_attributes.values.all?(&:blank?)

      evidence_attributes = Array(attributes['evidence_links_attributes']&.values)
      evidence_attributes.all? do |evidence_link_attributes|
        evidence_link_attributes.except('id', '_destroy', 'relation_type', 'review_status').values.all?(&:blank?)
      end
    end

    public

    def evidence_selector_options
      (
        default_evidence_selector_options +
        rich_text_evidence_selector_options +
        block_evidence_selector_options
      ).uniq { |option| option[:value] }
    end

    def claims_as_json_bundle # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      claims.includes(evidence_links: :citation).map do |claim|
        {
          id: claim.id,
          claim_key: claim.claim_key,
          statement: claim.statement,
          selector: claim.selector,
          review_status: claim.review_status,
          evidence_links: claim.evidence_links.map do |evidence_link|
            citation = evidence_link.citation

            {
              id: evidence_link.id,
              relation_type: evidence_link.relation_type,
              locator: evidence_link.locator,
              quoted_text: evidence_link.quoted_text,
              editor_note: evidence_link.editor_note,
              review_status: evidence_link.review_status,
              citation: citation && {
                id: citation.id,
                reference_key: citation.reference_key,
                title: citation.title,
                source_kind: citation.source_kind
              }
            }.compact
          end
        }.compact
      end
    end

    private

    def default_evidence_selector_options
      [{ value: 'record', label: 'Entire record' }]
    end

    def rich_text_evidence_selector_options
      RICH_TEXT_SELECTOR_ATTRIBUTES.filter_map do |attribute|
        next unless respond_to?(attribute)

        {
          value: "rich_text:#{attribute}",
          label: "#{attribute.to_s.humanize} rich text"
        }
      end
    end

    def block_evidence_selector_options
      blocks = []
      blocks << hero_block if respond_to?(:hero_block) && hero_block.present?
      blocks.concat(Array(content_blocks)) if respond_to?(:content_blocks)

      blocks.compact.map(&:evidence_selector_options)
            .flatten
    end
  end
end
