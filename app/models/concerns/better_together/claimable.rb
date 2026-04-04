# frozen_string_literal: true

module BetterTogether
  # Adds claim and evidence link support to published and contributed records.
  module Claimable
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

    class_methods do
      def extra_permitted_attributes
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
      claim_attributes = attributes.except('evidence_links_attributes')
      return false unless claim_attributes.values.all?(&:blank?)

      evidence_attributes = Array(attributes['evidence_links_attributes']&.values)
      evidence_attributes.all? do |evidence_link_attributes|
        evidence_link_attributes.except('id', '_destroy').values.all?(&:blank?)
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

      blocks.compact.map do |block|
        block.evidence_selector_options
      end
            .flatten
    end
  end
end
