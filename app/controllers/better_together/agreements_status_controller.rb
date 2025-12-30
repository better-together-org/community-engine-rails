# frozen_string_literal: true

module BetterTogether
  # Controller for managing required agreement acceptance status
  # Displays unaccepted required agreements and allows users to accept them
  # NOTE: This controller does NOT include ChecksRequiredAgreements to avoid redirect loops.
  # It is the destination controller for the required agreements check.
  class AgreementsStatusController < ApplicationController
    before_action :authenticate_user!
    before_action :load_unaccepted_agreements, only: %i[index create]

    # GET /agreements/status
    def index
      # If no unaccepted agreements, redirect to stored location or root
      if @unaccepted_agreements.empty?
        redirect_to stored_location_for(:user) || after_sign_in_path_for(current_user),
                    notice: t('.all_accepted')
        return
      end

      # Load all required agreements for display (both accepted and unaccepted)
      load_all_required_agreements
    end

    # POST /agreements/status
    def create
      if agreements_accepted?
        create_agreement_participants
        redirect_to stored_location_for(:user) || after_sign_in_path_for(current_user),
                    notice: t('.successfully_accepted')
      else
        flash.now[:alert] = t('.acceptance_required')
        load_all_required_agreements
        render :index
      end
    end

    private

    def load_unaccepted_agreements
      @unaccepted_agreements = current_user.person.unaccepted_required_agreements
    end

    def load_all_required_agreements
      required_identifiers = %w[privacy_policy terms_of_service]
      required_identifiers << 'code_of_conduct' if Agreement.exists?(identifier: 'code_of_conduct')

      all_required = Agreement.where(identifier: required_identifiers)
      accepted_ids = current_user.person.agreement_participants.pluck(:agreement_id)

      all_required.each do |agreement|
        instance_variable_set(
          "@#{agreement.identifier}_agreement",
          agreement
        )
        instance_variable_set(
          "@#{agreement.identifier}_accepted",
          accepted_ids.include?(agreement.id)
        )
      end
    end

    def agreements_accepted?
      required = []

      @unaccepted_agreements.each do |agreement|
        param_name = "#{agreement.identifier}_agreement"
        required << params[param_name]
      end

      required.all? { |v| v == '1' }
    end

    def create_agreement_participants
      @unaccepted_agreements.each do |agreement|
        param_name = "#{agreement.identifier}_agreement"
        next unless params[param_name] == '1'

        BetterTogether::AgreementParticipant.create!(
          agreement: agreement,
          person: current_user.person,
          accepted_at: Time.current
        )
      end
    end

    # Override default after_sign_in_path to respect stored location
    def after_sign_in_path_for(resource)
      stored_location_for(resource) || super
    end
  end
end
