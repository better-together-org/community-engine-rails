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
    has_many :agreement_participants, class_name: 'BetterTogether::AgreementParticipant', dependent: :destroy
    has_many :participants, through: :agreement_participants, source: :person

    accepts_nested_attributes_for :agreement_terms, reject_if: :all_blank, allow_destroy: true

    translates :title
    translates :description, backend: :action_text

    slugged :title
  end
end
