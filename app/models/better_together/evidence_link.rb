# frozen_string_literal: true

module BetterTogether
  # Joins a claim to a structured citation with relation semantics.
  class EvidenceLink < ApplicationRecord
    include Positioned
    include BetterTogether::Creatable

    RELATION_TYPES = %w[supports contests contextualizes documents].freeze
    REVIEW_STATUSES = BetterTogether::Claim::REVIEW_STATUSES

    belongs_to :claim, class_name: 'BetterTogether::Claim', inverse_of: :evidence_links
    belongs_to :citation, class_name: 'BetterTogether::Citation'

    validates :relation_type, inclusion: { in: RELATION_TYPES }
    validates :review_status, inclusion: { in: REVIEW_STATUSES }
    validates :citation_id, uniqueness: { scope: %i[claim_id relation_type] }
  end
end
