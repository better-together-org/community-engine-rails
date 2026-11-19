# frozen_string_literal: true

module BetterTogether
  # The terms of an agreement between participants
  class AgreementTerm < PlatformRecord
    include Identifier
    include PlatformFromParent
    include Positioned
    include Protected

    belongs_to :agreement, class_name: 'BetterTogether::Agreement'
    platform_from :agreement

    translates :summary
    translates :content, backend: :action_text
  end
end
