# frozen_string_literal: true

module BetterTogether
  # Statements agreed upon by its participants
  class Agreement < ApplicationRecord
    include Creatable
    include Identifier
    include Privacy
    include Protected

    has_many :agreement_participants, class_name: 'BetterTogether::AgreementParticipant', dependent: :destroy
    has_many :agreement_terms, -> { positioned }, class_name: 'BetterTogether::AgreementTerm'
    # Optional link to a Page: when set, the page's content will be shown
    # instead of the agreement's terms in the public agreement view.
    belongs_to :page, class_name: 'BetterTogether::Page', optional: true
    has_many :agreement_participants, class_name: 'BetterTogether::AgreementParticipant', dependent: :destroy
    has_many :participants, through: :agreement_participants, source: :person

    accepts_nested_attributes_for :agreement_terms, reject_if: :all_blank, allow_destroy: true

    translates :title, type: :string
    translates :description, backend: :action_text

    def self.permitted_attributes(id: false, destroy: false)
      super + [:page_id]
    end

    slugged :title
  end
end
