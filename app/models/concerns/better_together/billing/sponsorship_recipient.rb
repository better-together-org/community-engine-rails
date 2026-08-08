# frozen_string_literal: true

module BetterTogether
  module Billing
    # Include on any entity that can be a sponsorship beneficiary. Opt-in gate
    # mirrors Joinable#membership_requests_enabled? (a plain boolean column +
    # predicate method, not a scope) — being sponsorable is off by default.
    module SponsorshipRecipient
      extend ActiveSupport::Concern

      included do
        has_many :received_sponsorships,
                 as: :beneficiary,
                 class_name: 'BetterTogether::Billing::Sponsorship',
                 dependent: :restrict_with_error
      end

      def self.included_in_models
        included_module = self
        Rails.application.eager_load! unless Rails.env.production?
        ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
      end

      def accepts_sponsorship?
        return false unless has_attribute?(:accepts_sponsorship)

        ActiveModel::Type::Boolean.new.cast(self[:accepts_sponsorship])
      end

      def current_sponsorship
        received_sponsorships.status_active.order(created_at: :desc).first
      end
    end
  end
end
