# frozen_string_literal: true

module BetterTogether
  # Concern that checks if the current user has unaccepted required agreements
  # and redirects them to the agreements status page if needed.
  #
  # Usage:
  #   class MyController < ApplicationController
  #     include BetterTogether::ChecksRequiredAgreements
  #     before_action :check_required_agreements
  #   end
  #
  # To skip checking in specific actions:
  #   skip_before_action :check_required_agreements, only: [:index, :show]
  module ChecksRequiredAgreements
    extend ActiveSupport::Concern

    included do
      helper_method :current_person_has_unaccepted_agreements? if respond_to?(:helper_method)
    end

    # Returns required agreements that a person has not yet accepted
    # @param person [BetterTogether::Person] the person to check
    # @return [ActiveRecord::Relation<BetterTogether::Agreement>] unaccepted required agreements
    def self.unaccepted_required_agreements(person)
      required_identifiers = %w[privacy_policy terms_of_service]
      required_identifiers << 'code_of_conduct' if BetterTogether::Agreement.exists?(identifier: 'code_of_conduct')

      # Only count accepted participants (accepted_at not null)
      accepted_agreement_ids = person.agreement_participants.where.not(accepted_at: nil).pluck(:agreement_id)

      BetterTogether::Agreement
        .where(identifier: required_identifiers)
        .where.not(id: accepted_agreement_ids)
    end

    # Returns true if a person has unaccepted required agreements
    # @param person [BetterTogether::Person] the person to check
    # @return [Boolean]
    def self.person_has_unaccepted_required_agreements?(person)
      unaccepted_required_agreements(person).exists?
    end

    protected

    # Checks if the current user has unaccepted required agreements
    # and redirects to the agreements status page if they do.
    #
    # @return [void]
    def check_required_agreements
      return unless user_signed_in?
      return unless current_user.person.present?
      return unless current_person_has_unaccepted_agreements?

      # Store the intended destination so we can redirect back after accepting agreements
      store_location_for(:user, request.fullpath) unless request.fullpath == agreements_status_path

      redirect_to agreements_status_path, alert: t('better_together.agreements.status.acceptance_required')
    end

    # Returns true if the current user's person has unaccepted required agreements
    # @return [Boolean]
    def current_person_has_unaccepted_agreements?
      return false unless user_signed_in?
      return false unless current_user.person.present?

      BetterTogether::ChecksRequiredAgreements.person_has_unaccepted_required_agreements?(current_user.person)
    end

    # Helper method to get agreements_status_path
    # @return [String]
    def agreements_status_path
      better_together.agreements_status_path(locale: I18n.locale)
    end
  end
end
