module BetterTogether
  class Agreement < ApplicationRecord
    include Creatable
    include Identifier
    include Privacy
    include Protected

    has_many :agreement_terms, -> { positioned }, class_name: 'BetterTogether::AgreementTerm'

    accepts_nested_attributes_for :agreement_terms, reject_if: :all_blank, allow_destroy: true

    translates :title
    translates :description, backend: :action_text

    slugged :title
  end
end
