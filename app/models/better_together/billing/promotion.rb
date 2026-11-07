# frozen_string_literal: true

module BetterTogether
  module Billing
    # A code that gives store credit when a person redeems it.
    #
    # The code is a secret until it is used, so it is never stored: only a keyed digest (HMAC-SHA256 with a
    # key derived from the application's secret), unique per platform. The code is shown once, when the
    # promotion is made (see Promotions::Create), and cannot be read back. Looking one up is by digest, so a
    # database copy does not reveal codes and the digest cannot be guessed offline without the key.
    class Promotion < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_promotions'

      # Letters and digits that cannot be mistaken for each other (no 0/O, 1/I/L).
      ALPHABET = %w[A B C D E F G H J K M N P Q R S T U V W X Y Z 2 3 4 5 6 7 8 9].freeze
      CODE_LENGTH = 16
      DIGEST_PURPOSE = 'better_together/billing/promotion_code'

      belongs_to :created_by, class_name: 'BetterTogether::Person', optional: true
      has_many :redemptions, class_name: 'BetterTogether::Billing::PromotionRedemption', inverse_of: :promotion, dependent: :restrict_with_error

      attr_readonly :code_digest, :amount_cents, :currency

      validates :name, presence: true, length: { maximum: 120 }
      validates :code_digest, presence: true, uniqueness: { scope: :platform_id }
      validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
      validates :currency, inclusion: { in: Plan::SUPPORTED_CURRENCY_CODES }
      validates :credit_expires_after_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
      validates :max_redemptions, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
      validates :redemptions_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validate :window_in_order
      validate :purposes_known

      scope :active, -> { where(active: true) }

      class << self
        # The code as people type it: letters and digits only, upper case, so a pasted "abcd-efgh" works.
        def normalize(code) = code.to_s.upcase.gsub(/[^A-Z0-9]/, '')

        # The keyed digest a code is stored and looked up by.
        def digest_for(code)
          OpenSSL::HMAC.hexdigest('SHA256', digest_key, normalize(code))
        end

        # A new random code, grouped for reading aloud: XXXX-XXXX-XXXX-XXXX.
        def generate_code
          Array.new(CODE_LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.each_slice(4).map(&:join).join('-')
        end

        private

        def digest_key = Rails.application.key_generator.generate_key(DIGEST_PURPOSE, 32)
      end

      def started?(now = Time.current) = starts_at.nil? || starts_at <= now
      def ended?(now = Time.current) = ends_at.present? && ends_at <= now
      def exhausted? = max_redemptions.present? && redemptions_count >= max_redemptions
      def redeemable?(now = Time.current) = active? && started?(now) && !ended?(now) && !exhausted?

      private

      def window_in_order
        errors.add(:ends_at, :after_start) if starts_at && ends_at && ends_at <= starts_at
      end

      def purposes_known
        self.purposes = Array(purposes).map(&:to_s).compact_blank.uniq
        errors.add(:purposes, :inclusion) if (purposes - ProcessorSetting::PURPOSES).any?
      end
    end
  end
end
