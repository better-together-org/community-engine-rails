# frozen_string_literal: true

module BetterTogether
  # Controller for managing required agreement acceptance status
  # Displays unaccepted required agreements and allows users to accept them
  # NOTE: This controller does NOT include ChecksRequiredAgreements to avoid redirect loops.
  # It is the destination controller for the required agreements check.
  class AgreementsStatusController < ApplicationController # rubocop:todo Metrics/ClassLength
    before_action :authenticate_user!
    before_action :load_unaccepted_agreements, only: %i[index create]
    before_action :load_agreement_center, only: %i[index create]

    # GET /agreements/status
    def index
      # If no unaccepted agreements, redirect to stored location or root
      if @unaccepted_agreements.empty?
        redirect_to resolved_return_path(fallback: after_sign_in_path_for(current_user)),
                    notice: t('.all_accepted')
        return
      end

      load_all_required_agreements
    end

    # POST /agreements/status
    def create
      if agreements_accepted?
        create_agreement_participants
        redirect_to safe_return_to_path || person_path(current_user.person, locale: I18n.locale),
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
      return unless ENV['DEBUG_AGREEMENTS']

      Rails.logger.debug "[AGREEMENTS DEBUG] User: #{current_user.email}"
      Rails.logger.debug "[AGREEMENTS DEBUG] Unaccepted count: #{@unaccepted_agreements.count}"
      Rails.logger.debug "[AGREEMENTS DEBUG] Unaccepted IDs: #{@unaccepted_agreements.pluck(:identifier)}"
    end

    def load_all_required_agreements # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      required_identifiers = BetterTogether::ChecksRequiredAgreements.required_agreement_identifiers
      required_identifiers |= requested_agreement_identifiers

      all_required = Agreement.where(identifier: required_identifiers).ordered_for_consent
      @display_agreements = all_required.map do |agreement|
        acceptance_record = agreement.latest_acceptance_for(current_user.person)
        {
          agreement:,
          acceptance_record:,
          accepted: agreement.accepted_by?(current_user.person),
          stale: agreement.stale_acceptance_for(current_user.person).present?
        }
      end

      all_required.each do |agreement|
        acceptance_record = agreement.latest_acceptance_for(current_user.person)
        instance_variable_set(
          "@#{agreement.identifier}_agreement",
          agreement
        )
        instance_variable_set(
          "@#{agreement.identifier}_accepted",
          agreement.accepted_by?(current_user.person)
        )
        instance_variable_set(
          "@#{agreement.identifier}_stale",
          agreement.stale_acceptance_for(current_user.person).present?
        )
        instance_variable_set(
          "@#{agreement.identifier}_acceptance_record",
          acceptance_record
        )
      end
    end

    def load_agreement_center
      @acceptance_history = current_user.person.accepted_agreement_participants
      @current_acceptances = @acceptance_history.select(&:current_for_agreement?)
      @stale_acceptances = @acceptance_history.select(&:stale_for_agreement?)
    end

    def agreements_accepted?
      @unaccepted_agreements.all? do |agreement|
        params[helpers.agreement_acceptance_param_name(agreement)] == '1'
      end
    end

    def create_agreement_participants
      @unaccepted_agreements.each do |agreement|
        param_name = helpers.agreement_acceptance_param_name(agreement)
        next unless params[param_name] == '1'

        BetterTogether::AgreementAcceptanceRecorder.record!(
          agreement: agreement,
          participant: current_user.person,
          acceptance_method: :agreement_review,
          accepted_at: Time.current,
          context: { request:, flow: 'agreements_status' }
        )
      end
    end

    def requested_agreement_identifiers
      return [] unless params[:agreement].present?

      Array(params[:agreement]).map(&:to_s).select do |identifier|
        identifier == BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER
      end
    end

    # Override default after_sign_in_path to respect stored location
    def after_sign_in_path_for(resource)
      stored_location_for(resource) || super
    end

    def safe_return_to_path
      path = params[:return_to].to_s
      return if path.blank?

      url_from(path)
    end

    def resolved_return_path(fallback:)
      safe_return_to_path || url_from(stored_location_for(:user)) || fallback
    end
  end
end
