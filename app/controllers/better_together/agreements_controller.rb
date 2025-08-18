# frozen_string_literal: true

module BetterTogether
  # CRUD for Agreements
  class AgreementsController < FriendlyResourceController
    skip_before_action :check_platform_privacy, only: :show

    protected

    def resource_class
      ::BetterTogether::Agreement
    end
  end
end
