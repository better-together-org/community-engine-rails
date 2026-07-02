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
  module ChecksRequiredAgreements # rubocop:todo Metrics/ModuleLength
    extend ActiveSupport::Concern

    COMMUNITY_CREATION_AGREEMENT_IDENTIFIER = 'community_creation_agreement'

    included do
      helper_method :current_person_has_unaccepted_agreements? if respond_to?(:helper_method)
      helper_method :current_person_missing_publishing_agreement? if respond_to?(:helper_method)
      helper_method :current_person_missing_community_creation_agreement? if respond_to?(:helper_method)
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

    def self.public_community_creation_agreement
      BetterTogether::Agreement.find_by(identifier: COMMUNITY_CREATION_AGREEMENT_IDENTIFIER)
    end

    def self.accepted_community_creation_agreement?(participant)
      accepted_agreement?(participant, identifier: COMMUNITY_CREATION_AGREEMENT_IDENTIFIER)
    end

    def self.missing_community_creation_agreement?(participant)
      !accepted_community_creation_agreement?(participant)
    end

    # Returns required agreements that a person has not yet accepted.
    # Acceptance is evaluated via +Agreement#accepted_by?+ (which respects staleness) so the
    # accepted IDs are resolved in Ruby; the result is then returned as an
    # ActiveRecord::Relation so callers may chain further scopes or use relation methods.
    # @param person [BetterTogether::Person] the person to check
    # @return [ActiveRecord::Relation<BetterTogether::Agreement>] unaccepted required agreements
    def self.unaccepted_required_agreements(person)
      base = BetterTogether::Agreement
             .required_for_registration
             .ordered_for_consent

      return base if person.blank?

      accepted_ids = base.select { |agreement| agreement.accepted_by?(person) }.map(&:id)
      accepted_ids.empty? ? base : base.where.not(id: accepted_ids)
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

    # Checks if the current user has accepted the content publishing agreement.
    # Redirects directly to the publishing agreement page when it is missing so
    # the user can read and accept it before proceeding to content creation.
    def check_publishing_agreement
      return unless user_signed_in? && current_user.person.present?

      publishing_agreement = ChecksRequiredAgreements.public_publishing_agreement
      return unless publishing_agreement.present? && current_person_missing_publishing_agreement?

      store_location_for(:user, request.fullpath)
      redirect_to_publishing_agreement(publishing_agreement)
    end

    # Returns true if the current person has not yet accepted the publishing agreement.
    # @return [Boolean]
    def current_person_missing_publishing_agreement?
      return false unless user_signed_in?
      return false unless current_user.person.present?

      ChecksRequiredAgreements.missing_public_publishing_agreement?(current_user.person)
    end

    # Returns true if the current person has not yet accepted the community creation agreement.
    # @return [Boolean]
    def current_person_missing_community_creation_agreement?
      return false unless user_signed_in?
      return false unless current_user.person.present?

      ChecksRequiredAgreements.missing_community_creation_agreement?(current_user.person)
    end

    # Redirects to the community creation agreement when the current person hasn't accepted it.
    # Platform managers are exempt — they can always create communities.
    # Call this as a before_action on community new/create actions.
    def check_community_creation_agreement
      return unless user_signed_in? && current_user.person.present?

      agreement = ChecksRequiredAgreements.public_community_creation_agreement
      return unless agreement.present? && current_person_missing_community_creation_agreement?

      # Platform managers bypass the community creation agreement requirement
      return if current_person_is_platform_manager?

      store_location_for(:user, request.fullpath)
      redirect_to better_together.agreement_path(agreement, locale: I18n.locale),
                  alert: t('better_together.agreements.community_creation_agreement_required')
    end

    # Helper method to get agreements_status_path
    # @return [String]
    def agreements_status_path
      better_together.agreements_status_path(locale: I18n.locale)
    end

    def redirect_to_publishing_agreement(agreement)
      redirect_to better_together.agreement_path(agreement, locale: I18n.locale),
                  alert: t('better_together.agreements.publishing_agreement_required')
    end

    # Returns true if the current person holds a platform role with management permissions.
    # Used to exempt platform managers from community creation agreement requirements.
    def current_person_is_platform_manager?
      return false unless user_signed_in? && current_user.person.present?

      manager_permission_ids = BetterTogether::ResourcePermission
                               .where(identifier: %w[manage_platform_settings manage_platform])
                               .pluck(:id)
      return false if manager_permission_ids.empty?

      BetterTogether::PersonPlatformMembership
        .active
        .where(member: current_user.person)
        .joins(role: :role_resource_permissions)
        .where(
          better_together_role_resource_permissions: { resource_permission_id: manager_permission_ids }
        )
        .exists?
    end
  end
end
