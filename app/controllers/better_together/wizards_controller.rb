# frozen_string_literal: true

# app/controllers/better_together/wizards_controller.rb
module BetterTogether
  # Handles wizard requests
  class WizardsController < ApplicationController
    include ::BetterTogether::WizardMethods

    def show
      @wizard = ::BetterTogether::Wizard.friendly.find(params[:id])
      determine_wizard_outcome(@wizard)
    end
  end
end
