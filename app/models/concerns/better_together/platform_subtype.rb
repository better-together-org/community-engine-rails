# frozen_string_literal: true

module BetterTogether
  # Shared behaviour for Platform subtypes (STI on the type column). A subtype stays a Platform to routes, forms,
  # policies and the role set, so it borrows the base model name and policy.
  module PlatformSubtype
    extend ActiveSupport::Concern

    REMOTE_ONLY_TYPES = %w[BetterTogether::OauthPlatform BetterTogether::FederatedPlatform].freeze

    included do
      validate :locality_matches_type
    end

    class_methods do
      def model_name
        BetterTogether::Platform.model_name
      end

      def policy_class
        BetterTogether::PlatformPolicy
      end
    end

    private

    # OAuth providers and federated peers are never served by this instance. Operator and hosted platforms may
    # be local or remote, except the host row, which is the instance itself.
    def locality_matches_type
      errors.add(:locality, :invalid) if REMOTE_ONLY_TYPES.include?(self.class.name) && !remote?
      errors.add(:locality, :invalid) if host? && remote?
    end
  end
end
