# frozen_string_literal: true

module BetterTogether
  # A specific published or internal assertion that can be linked to evidence.
  class Claim < ApplicationRecord
    include Positioned
    include BetterTogether::Creatable

    REVIEW_STATUSES = %w[draft reviewed accepted challenged].freeze

    belongs_to :claimable, polymorphic: true
    has_many :evidence_links,
             -> { order(:position, :created_at) },
             class_name: 'BetterTogether::EvidenceLink',
             dependent: :destroy,
             inverse_of: :claim
    has_many :citations, through: :evidence_links

    accepts_nested_attributes_for :evidence_links, allow_destroy: true, reject_if: :all_blank

    before_validation :normalize_claim_key

    validates :claim_key, presence: true, format: { with: /\A[a-z0-9_-]+\z/ }
    validates :statement, presence: true
    validates :review_status, inclusion: { in: REVIEW_STATUSES }
    validates :claim_key, uniqueness: { scope: %i[claimable_type claimable_id] }

    def anchor_id
      "claim-#{claim_key}"
    end

    private

    def normalize_claim_key
      candidate = claim_key.presence || statement.to_s.parameterize(separator: '_')
      self.claim_key = candidate.to_s.downcase.gsub(/[^a-z0-9_-]/, '_').squeeze('_').presence || 'claim'
    end
  end
end
