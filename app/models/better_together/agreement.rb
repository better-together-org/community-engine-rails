# frozen_string_literal: true

require 'digest'

module BetterTogether
  # Statements agreed upon by its participants
  class Agreement < ApplicationRecord
    include Citable
    include Claimable
    include Creatable
    include Identifier
    include Privacy
    include Protected

    has_many :agreement_participants, class_name: 'BetterTogether::AgreementParticipant', dependent: :destroy
    has_many :agreement_terms, -> { positioned }, class_name: 'BetterTogether::AgreementTerm'
    # Optional link to a Page: when set, the page's content will be shown
    # instead of the agreement's terms in the public agreement view.
    belongs_to :page, class_name: 'BetterTogether::Page', optional: true
    has_many :participants, through: :agreement_participants, source: :person

    accepts_nested_attributes_for :agreement_terms, reject_if: :all_blank, allow_destroy: true

    translates :title, type: :string
    translates :description, backend: :action_text

    def acceptance_audit_snapshot
      snapshot_attributes.merge('terms' => agreement_term_snapshots)
    end

    def acceptance_content_digest
      Digest::SHA256.hexdigest(acceptance_audit_snapshot.to_json)
    end

    def self.permitted_attributes(id: false, destroy: false)
      super + [:page_id]
    end

    slugged :title

    private

    def snapshot_attributes
      {
        identifier: identifier.to_s,
        title: title.to_s,
        description: description.to_plain_text.to_s,
        page_id: page_id,
        updated_at: updated_at&.utc&.iso8601(6)
      }.deep_stringify_keys
    end

    def agreement_term_snapshots
      agreement_terms.map do |term|
        {
          'position' => term.position,
          'summary' => term.summary.to_s,
          'content' => term.content.to_plain_text.to_s
        }
      end
    end
  end
end
