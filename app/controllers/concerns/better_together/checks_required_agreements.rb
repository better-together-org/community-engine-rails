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

    def self.required_agreement_identifiers
      BetterTogether::Agreement.registration_consent_records.map(&:identifier)
    end

    def self.accepted_agreement?(participant, identifier:)
      return false unless participant.present?

      agreement = BetterTogether::Agreement.find_by(identifier:)
      return false unless agreement

      agreement.accepted_by?(participant)
    end

    def self.public_publishing_agreement
      BetterTogether::Agreement.first_publish_consent_record
    end

    def self.accepted_public_publishing_agreement?(participant)
      accepted_agreement?(participant, identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER)
    end

    def self.missing_public_publishing_agreement?(participant)
      !accepted_public_publishing_agreement?(participant)
    end

    # Returns required agreements that a person has not yet accepted
    # @param person [BetterTogether::Person] the person to check
    # @return [ActiveRecord::Relation<BetterTogether::Agreement>] unaccepted required agreements
    def self.unaccepted_required_agreements(person)
      BetterTogether::Agreement
        .required_for_registration
        .ordered_for_consent
        .reject { |agreement| agreement.accepted_by?(person) }
    end

    # Returns true if a person has unaccepted required agreements
    # @param person [BetterTogether::Person] the person to check
    # @return [Boolean]
    def self.person_has_unaccepted_required_agreements?(person)
      unaccepted_required_agreements(person).any?
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
