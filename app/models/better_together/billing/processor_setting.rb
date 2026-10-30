# frozen_string_literal: true

module BetterTogether
  module Billing
    # Whether a payment method outside a vendor (cash, cheque, e-transfer) is switched on for
    # a platform or one of its sellers, and what buyers are told so they can pay.
    #
    # The methods are installed for everyone, but a method works for a seller only once a
    # steward has enabled it here and acknowledged what it cannot do: the platform cannot
    # track it, take a fee on it, or protect the buyer (see docs/billing/payment_methods.md).
    #
    # `settings` holds where to send the payment, so it is encrypted at rest and is shown only
    # to a steward and to a buyer on their own order. Every change writes a billing event
    # that names the fields changed and never their values.
    class ProcessorSetting < ApplicationRecord
      include PlatformBound
      include SellerScoped
      include EncryptedAttributes
      include Subjectable
      include SettingAudit

      self.table_name = 'better_together_billing_processor_settings'

      PURPOSES = %w[subscription one_time ticket exchange].freeze
      MIN_HOLD_HOURS = 1
      MAX_HOLD_HOURS = 24 * 30
      VALUE_LIMIT = 1_000

      encrypts_billing_attribute :settings, json: true, default: -> { {} }

      belongs_to :acknowledged_by, class_name: 'BetterTogether::Person', optional: true

      # The steward ticked "I understand" on the form. Not stored; it sets the acknowledgement.
      attribute :acknowledge, :boolean, default: false
      # Who is making the change, for the audit event. Not stored.
      attr_accessor :changed_by

      attr_readonly :processor

      before_validation :normalize
      before_validation :record_acknowledgement

      validates :processor, presence: true
      validates :processor, uniqueness: { scope: %i[platform_id seller_type seller_id] }
      validate :processor_is_an_offline_method
      validates :hold_hours, numericality: { only_integer: true, greater_than_or_equal_to: MIN_HOLD_HOURS,
                                             less_than_or_equal_to: MAX_HOLD_HOURS }
      validate :purposes_known
      validate :grant_on_allowed
      validate :settings_known
      validate :settings_short
      validate :ready_to_enable, if: :enabled?

      scope :enabled, -> { where(enabled: true) }

      def adapter
        @adapter ||= Billing.offline_method?(processor) ? Billing.processor_adapter(processor) : nil
      end

      # When a buyer's access starts; the adapter's default until the seller chooses.
      def grant_on
        super.presence || adapter&.default_grant_on
      end

      def acknowledged? = acknowledged_at.present?

      def allows?(purpose) = purposes.include?(purpose.to_s)

      # The country the platform sells from, when it has said. Used to refuse a method that
      # does not exist there. Sellers have no country on record yet, so theirs is unknown.
      def country
        return unless sold_by_platform?

        Configuration.default_country
      end

      # What the buyer sees to pay: only the fields the adapter declares, only if non-blank.
      def instructions
        adapter ? adapter.instructions_for(setting: self) : {}
      end

      private

      def normalize
        self.processor = processor.to_s.presence
        self.grant_on = nil if self[:grant_on].to_s.blank?
        normalize_lists
      end

      def normalize_lists
        self.purposes = Array(purposes).map { |purpose| purpose.to_s.strip }.compact_blank.uniq
        self.settings = settings.to_h.transform_keys(&:to_s).transform_values { |value| value.to_s.strip }.compact_blank
      end

      # Acknowledging is a one-way step recorded with who and when.
      def record_acknowledgement
        return unless acknowledge && acknowledged_at.nil?

        self.acknowledged_at = Time.current
        self.acknowledged_by = changed_by if changed_by.is_a?(BetterTogether::Person)
      end

      def processor_is_an_offline_method
        return if processor.blank? || adapter

        errors.add(:processor, :not_an_offline_method, method: processor)
      end

      def purposes_known
        errors.add(:purposes, :blank) if purposes.empty?
        unknown = purposes - PURPOSES
        errors.add(:purposes, :inclusion) if unknown.any?
      end

      def grant_on_allowed
        return unless adapter && self[:grant_on].present?

        errors.add(:grant_on, :inclusion) unless adapter.grant_on_options.include?(self[:grant_on])
      end

      # Only the fields the method declares, each of a sensible length.
      def settings_known
        return unless adapter

        unknown = settings.keys - adapter.instruction_fields.map { |field| field.name.to_s }
        errors.add(:settings, :unknown_setting, fields: unknown.join(', ')) if unknown.any?
      end

      def settings_short
        errors.add(:settings, :too_long, count: VALUE_LIMIT) if settings.values.any? { |value| value.length > VALUE_LIMIT }
      end

      # Checks that only matter once the method is switched on.
      def ready_to_enable
        return unless adapter

        errors.add(:acknowledge, :acknowledgement_required) unless acknowledged?
        adapter.settings_errors(settings).each { |field, code| errors.add(:settings, code, field:) }
        errors.add(:processor, :country_not_supported, country:) if unsupported_country?
      end

      def unsupported_country?
        countries = adapter.supported_countries
        countries.present? && country.present? && countries.exclude?(country)
      end
    end
  end
end
