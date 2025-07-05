# frozen_string_literal: true

module BetterTogether
  # CRUD for Agreements
  class AgreementsController < FriendlyResourceController
    protected

    def resource_class
      ::BetterTogether::Agreement
    end
  end
end
