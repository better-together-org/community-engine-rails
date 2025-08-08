# frozen_string_literal: true

module BetterTogether
  # The terms of an agreement between participants
  class AgreementTerm < ApplicationRecord
    include Identifier
    include Positioned
    include Protected

    belongs_to :agreement, class_name: 'BetterTogether::Agreement'

    translates :summary
    translates :content, backend: :action_text
  end
end
