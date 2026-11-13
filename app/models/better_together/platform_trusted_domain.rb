# frozen_string_literal: true

module BetterTogether
  # An email domain a platform steward trusts: a person whose verified address is on it may register
  # without an invitation and joins the platform's community with `role`. Exact match on the part after
  # the final `@` unless include_subdomains is set. Per platform; removal never touches existing accounts.
  class PlatformTrustedDomain < ApplicationRecord # rubocop:todo Metrics/ClassLength
    DEFAULT_ROLE_IDENTIFIER = 'community_member'
    # Management-level roles may never be granted by an email domain, even with confirmation.
    DENIED_ROLE_IDENTIFIERS = %w[
      community_governance_council community_organizer community_coordinator community_strategist
    ].freeze
    PUBLIC_MAIL_DOMAINS = %w[
      gmail.com googlemail.com outlook.com hotmail.com live.com msn.com yahoo.com yahoo.ca ymail.com
      icloud.com me.com mac.com aol.com proton.me protonmail.com pm.me gmx.com gmx.net mail.com
      zoho.com yandex.com fastmail.com hey.com tutanota.com tuta.io sympatico.ca bell.net rogers.com
      shaw.ca telus.net eastlink.ca nl.rogers.com
    ].freeze
    DOMAIN_FORMAT = /\A(?=.{1,253}\z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,61}[a-z0-9]\z/

    belongs_to :platform, class_name: '::BetterTogether::Platform', inverse_of: :platform_trusted_domains
    belongs_to :role, class_name: '::BetterTogether::Role'
    belongs_to :created_by, class_name: '::BetterTogether::Person', optional: true
    has_many :trusted_domain_events, class_name: '::BetterTogether::TrustedDomainEvent', dependent: :nullify

    before_validation :normalize_domain
    before_validation :assign_default_role, if: -> { role_id.blank? }

    validates :domain, presence: true, format: { with: DOMAIN_FORMAT, allow_blank: true },
                       uniqueness: { scope: :platform_id }
    validates :note, length: { maximum: 500 }
    validate :role_is_a_community_role
    validate :role_within_ceiling
    validate :public_domain_is_confirmed

    scope :enabled, -> { where(enabled: true) }

    class << self
      # The enabled trusted domain covering this address, or nil. Only a verified address can match:
      # anyone can type an address they do not control.
      def match(platform:, email:, verified:)
        return nil unless verified == true && platform.present?

        host = email_host(email)
        return nil if host.blank?

        candidates = where(platform:).enabled
        candidates.find_by(domain: host) ||
          candidates.where(include_subdomains: true).find { |entry| host.end_with?(".#{entry.domain}") }
      end

      # Lower-cased ASCII (punycode) host after the final @, or nil for anything that is not an address.
      def email_host(email)
        address = email.to_s.strip
        return nil unless address.match?(URI::MailTo::EMAIL_REGEXP)

        normalize_host(address.split('@').last)
      end

      def normalize_host(value)
        host = value.to_s.strip.downcase.delete_prefix('@').chomp('.')
        return nil if host.blank?

        Addressable::IDNA.to_ascii(host)
      rescue Addressable::IDNA::PunycodeBigOutput, ArgumentError
        nil
      end
    end

    def public_mail_domain?
      PUBLIC_MAIL_DOMAINS.include?(domain)
    end

    def default_role?
      role&.identifier == DEFAULT_ROLE_IDENTIFIER
    end

    def to_s
      domain
    end

    private

    def normalize_domain
      self.domain = self.class.normalize_host(domain) || domain.to_s.strip.downcase
    end

    def assign_default_role
      self.role = ::BetterTogether::Role.find_by(identifier: DEFAULT_ROLE_IDENTIFIER,
                                                 resource_type: 'BetterTogether::Community')
    end

    def role_is_a_community_role
      return if role.blank? || role.resource_type == 'BetterTogether::Community'

      errors.add(:role, :not_a_community_role)
    end

    def role_within_ceiling
      return if role.blank? || default_role?

      if DENIED_ROLE_IDENTIFIERS.include?(role.identifier)
        errors.add(:role, :denied_for_trusted_domain)
      elsif !role_ceiling_confirmed
        errors.add(:role_ceiling_confirmed, :required_for_elevated_role)
      end
    end

    def public_domain_is_confirmed
      return unless public_mail_domain? && !public_domain_confirmed

      errors.add(:domain, :public_mail_domain)
    end
  end
end
