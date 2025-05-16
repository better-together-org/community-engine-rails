module BetterTogether
  class AgreementsController < FriendlyResourceController
    protected

    def resource_class
      ::BetterTogether::Agreement
    end
  end
end
