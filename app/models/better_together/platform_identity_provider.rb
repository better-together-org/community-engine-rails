# frozen_string_literal: true

module BetterTogether
  # Per-platform sign-in configuration for one external provider Platform
  # (e.g. the external "github" Platform). `strategy` names the catalog entry.
  class PlatformIdentityProvider < ApplicationRecord # rubocop:todo Metrics/ClassLength
    encrypts :client_secret

    # Keep the secret out of #inspect, error reports and serialization (encrypts already filters inspect).
    self.filter_attributes += %i[client_secret]

    normalizes :client_id, :client_secret, with: ->(value) { value.to_s.strip.presence }

    validates :client_id, :client_secret,
              format: { without: /[[:cntrl:]\s]/, message: :invalid_characters }, allow_nil: true

    belongs_to :platform, class_name: '::BetterTogether::Platform'
    belongs_to :provider_platform, class_name: '::BetterTogether::Platform'

    # Domains (callback hosts) this configuration may serve; sign-in is refused anywhere else.
    has_many :provider_domains, class_name: '::BetterTogether::PlatformIdentityProviderDomain',
                                dependent: :destroy, inverse_of: :platform_identity_provider
    has_many :platform_domains, through: :provider_domains, class_name: '::BetterTogether::PlatformDomain'

    validates :strategy, presence: true,
                         inclusion: { in: ->(_) { BetterTogether::IdentityProviders.keys.map(&:to_s) } }
    validates :provider_platform_id, uniqueness: { scope: :platform_id }
    validate :provider_platform_is_external

    # OpenID Connect issuer (stored in options); required by catalog entries with requires_issuer.
    # `label` names the sign-in button; `trust_verified_email` lets an issuer's email_verified claim link
    # an existing account (off by default: an issuer can assert any address).
    store_accessor :options, :issuer, :label, :trust_verified_email
    validates :issuer, presence: true, if: -> { catalog_entry&.requires_issuer }
    validate :issuer_is_safe_https_url, if: -> { issuer.present? }
    validate :issuer_unchanged, on: :update
    validates :label, length: { maximum: 80 }

    before_validation :normalize_issuer
    before_validation :assign_provider_platform, if: :needs_provider_platform?

    scope :enabled, -> { where(enabled: true) }

    after_commit :audit_configuration_change

    AUDITED_FIELDS = %w[enabled strategy client_id scopes options].freeze

    def serializable_hash(options = nil)
      super(options.to_h.merge(except: Array(options.to_h[:except]) + %w[client_secret]))
    end

    def catalog_entry
      BetterTogether::IdentityProviders.find(strategy)
    end

    def trust_verified_email?
      ActiveModel::Type::Boolean.new.cast(trust_verified_email) == true
    end

    # Text for the sign-in button: the organizer's label, else the issuer host.
    def display_name
      label.presence || issuer_host || catalog_entry&.kind
    end

    def issuer_host
      URI.parse(issuer.to_s).host.presence
    rescue URI::InvalidURIError
      nil
    end

    private

    # Record who-affecting changes without values: the secret never appears, only that it changed.
    def audit_configuration_change
      action = if destroyed? then 'identity_provider.destroyed'
               elsif previously_new_record? then 'identity_provider.created'
               else 'identity_provider.updated'
               end
      changed = (saved_changes.keys & (AUDITED_FIELDS + %w[client_secret])).sort
      return if action.end_with?('updated') && changed.empty?

      BetterTogether::TenancyAudit.record(action, identity_provider_id: id, owner_platform_id: platform_id,
                                                  strategy:, changed:, trust_verified_email: trust_verified_email?)
    end

    def issuer_provider?
      catalog_entry&.requires_issuer == true
    end

    def needs_provider_platform?
      return provider_platform.nil? unless issuer_provider?

      issuer_valid_url? && provider_platform&.identifier != issuer_platform_identifier
    end

    # The external Platform that represents this provider (seeded by ExternalPlatformBuilder). Issuer-based
    # providers get one external Platform per issuer, so identities from different issuers never mix.
    def assign_provider_platform
      return self.provider_platform = issuer_platform if issuer_provider?

      identifier = catalog_entry&.platform_identifier
      return if identifier.blank?

      self.provider_platform = PersonPlatformIntegration.find_external_platform_for_provider(strategy) ||
                               Platform.find_by(identifier:, external: true)
    end

    def issuer_platform_identifier
      "oidc-#{Digest::SHA256.hexdigest(issuer)[0, 16]}"
    end

    def issuer_platform
      Platform.external.find_or_create_by!(identifier: issuer_platform_identifier) do |platform|
        platform.name = issuer_host
        platform.url = issuer
        platform.description = "OpenID Connect issuer #{issuer}"
        platform.time_zone = 'UTC'
        platform.privacy = :public
        platform.host = false
      end
    rescue ActiveRecord::RecordInvalid
      nil # an unsafe or unusable issuer URL; the issuer validation reports it
    end

    # One canonical spelling per issuer, so the same issuer cannot be configured twice under variants.
    def normalize_issuer
      return if issuer.blank?

      self.issuer = canonical_issuer(issuer.to_s.strip)
    end

    def canonical_issuer(value)
      uri = URI.parse(value)
      return value unless uri.is_a?(URI::HTTPS) && uri.host

      uri.host = uri.host.downcase
      uri.fragment = nil
      uri.path = uri.path.to_s.chomp('/')
      uri.to_s
    rescue URI::InvalidURIError
      value
    end

    def issuer_valid_url?
      issuer.present? && URI.parse(issuer).is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end

    # Identities are keyed to the issuer, so it cannot change after creation; delete and recreate instead.
    def issuer_unchanged
      return unless issuer_provider? && options_changed?
      return if options_was.to_h['issuer'] == issuer

      errors.add(:issuer, :immutable)
    end

    def issuer_is_safe_https_url
      errors.add(:issuer, :invalid) unless URI.parse(issuer.to_s).is_a?(URI::HTTPS)
      BetterTogether::SafeFederationUrlValidator.new(attributes: [:issuer]).validate_each(self, :issuer, issuer)
      issuer_must_resolve_publicly
    rescue URI::InvalidURIError
      errors.add(:issuer, :invalid)
    end

    # Resolve DNS too: a name pointing at a private address is as unsafe as a private literal.
    # Only when the issuer is new or changing, or the provider is being turned on: an existing
    # provider whose DNS has since gone bad must still be editable and disableable.
    def issuer_must_resolve_publicly
      return if errors.include?(:issuer) || !issuer_dns_check_needed?
      return if BetterTogether::SafeOutboundHost.public_host?(URI.parse(issuer).host)

      errors.add(:issuer, :private_ip, message: I18n.t('better_together.validators.safe_federation_url.private_ip'))
    end

    def issuer_dns_check_needed?
      new_record? || will_save_change_to_options? || will_save_change_to_enabled?(to: true)
    end

    def provider_platform_is_external
      return if provider_platform.nil? || provider_platform.external?

      errors.add(:provider_platform, :invalid)
    end
  end
end
