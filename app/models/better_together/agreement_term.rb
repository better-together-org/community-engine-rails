module BetterTogether
  class AgreementTerm < ApplicationRecord
    include Identifier
    include Positioned
    include Protected

    belongs_to :agreement, class_name: 'BetterTogether::Agreement'

    translates :content, backend: :action_text
  end
end
