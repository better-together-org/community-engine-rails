# frozen_string_literal: true

module BetterTogether
  # joins people to agreements they have accepted
  class AgreementParticipant < ApplicationRecord
    belongs_to :agreement, class_name: 'BetterTogether::Agreement'
    belongs_to :person, class_name: 'BetterTogether::Person'

    validates :agreement_id, uniqueness: { scope: :person_id }
  end
end
