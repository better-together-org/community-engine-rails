# frozen_string_literal: true

# app/controllers/better_together/wizards_controller.rb
module BetterTogether
  # Handles wizard requests
  class WizardsController < ApplicationController
    include ::BetterTogether::WizardMethods

    def show
      platform = Current.platform || ::BetterTogether::Platform.find_by(host: true)
      @wizard = ::BetterTogether::Wizard.for_identifier(params[:id], platform:) ||
                ::BetterTogether::Wizard.friendly.find(params[:id])
      determine_wizard_outcome(@wizard)
    end
  end
end
