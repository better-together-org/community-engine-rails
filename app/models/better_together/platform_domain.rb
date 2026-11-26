# frozen_string_literal: true

module BetterTogether
  # Maps inbound hostnames to platforms and their canonical primary/share domains.
  class PlatformDomain < ApplicationRecord
    include BetterTogether::PrimaryFlag

    primary_flag_scope :platform_id

    # Backward-compatible attribute alias: existing code using .primary / .primary= / .primary?
    # continues to work after the column rename to primary_flag.
    alias_attribute :primary, :primary_flag

    belongs_to :platform, class_name: '::BetterTogether::Platform'

    scope :active,              -> { where(active: true) }
    scope :primary,             -> { where(primary_flag: true) }
    scope :as_share_domain,     -> { where(share_domain: true) }
    scope :share_domain_active, -> { as_share_domain.active }

    has_many :platform_identity_provider_domains, class_name: '::BetterTogether::PlatformIdentityProviderDomain',
                                                  dependent: :destroy

    before_validation :normalize_hostname!
    after_commit      :bust_resolve_cache

    # Auto-set share_domain=true when this is the first domain for the platform —
    # mirrors PrimaryFlag#set_default_primary_flag.
    after_initialize :set_default_share_domain, if: :new_record?

    # Radio-button toggle: setting share_domain=true on this record clears all siblings.
    before_save :enforce_single_share_domain, if: -> { share_domain? && share_domain_changed? }

    validates :hostname,     presence: true, uniqueness: { case_sensitive: false }
    validates :active,       inclusion: { in: [true, false] }
    validates :share_domain, inclusion: { in: [true, false] }

    validate :primary_domain_must_be_active, if: :primary_flag?
    validate :share_domain_must_be_active,   if: :share_domain?

    # Set by the controller when the actor is a platform steward and not the governing operator. A stewarded
    # domain must sit one label under an allowed zone, avoid reserved names, and starts inactive until an
    # operator activates it. Provisioning, seeds and operator-created domains leave this unset.
    attr_accessor :steward_requested

    before_validation :start_stewarded_domain_inactive, on: :create, if: :steward_requested
    validate :stewarded_hostname_allowed, if: -> { steward_requested && (new_record? || hostname_changed?) }
    validate :stewarded_change_allowed, on: :update, if: :steward_requested

    def self.resolve(hostname)
      normalized = normalize_hostname(hostname)
      Rails.cache.fetch("bt:platform_domain:#{normalized}", expires_in: 5.minutes) do
        active.find_by(hostname: normalized)
      end
    end

    # Zones a steward may request subdomains in: the host platform's own primary domain plus configured zones.
    def self.allowed_zones
      host_zone = BetterTogether::Platform.find_by(host: true)&.primary_platform_domain&.hostname
      ([host_zone] + Array(BetterTogether.platform_domain_zones)).compact.map { |zone| normalize_hostname(zone) }.uniq
    end

    def self.normalize_hostname(hostname)
      hostname.to_s.strip.downcase.sub(/\.$/, '')
    end

    # The domain's address. The scheme and, when the platform's host_url is this same hostname, its
    # nonstandard port (localhost:3000) carry over, so links keep pointing at the running app.
    def url
      base = host_url_uri
      scheme = base&.scheme.presence || 'https'
      port = base.port if base&.host.present? && self.class.normalize_hostname(base.host) == hostname &&
                          base.port != base.default_port
      "#{scheme}://#{hostname}#{":#{port}" if port}"
    end

    def normalize_hostname!
      self.hostname = self.class.normalize_hostname(hostname)
    end

    private

    def start_stewarded_domain_inactive
      self.active = false
      self.primary_flag = false
      self.share_domain = false
    end

    def stewarded_hostname_allowed
      zones = self.class.allowed_zones
      label = label_under_zone(zones)
      if label.nil? || label.include?('.')
        errors.add(:hostname, :outside_allowed_zone, zones: zones.join(', '))
      elsif BetterTogether.reserved_domain_labels.include?(label)
        errors.add(:hostname, :reserved)
      end
    end

    def label_under_zone(zones)
      zone = zones.find { |candidate| hostname.to_s.end_with?(".#{candidate}") }
      hostname.to_s.delete_suffix(".#{zone}") if zone
    end

    def stewarded_change_allowed
      errors.add(:hostname, :operator_only) if hostname_changed? && hostname_was.present? && active_was
      errors.add(:active, :operator_only) if active_changed? && active?
    end

    def set_default_share_domain
      return unless platform_id

      if self.class.where(platform_id:, share_domain: true).exists?
        self.share_domain ||= false
      else
        self.share_domain = true
      end
    end

    def enforce_single_share_domain
      self.class.where(platform_id:, share_domain: true).where.not(id:)
          .update_all(share_domain: false)
    end

    def primary_domain_must_be_active
      return if active?

      errors.add(:active, :must_be_true_for_primary)
    end

    def share_domain_must_be_active
      return if active?

      errors.add(:active, :must_be_true_for_share_domain)
    end

    def bust_resolve_cache
      Rails.cache.delete("bt:platform_domain:#{hostname}")
      Rails.cache.delete("bt:platform_domain:#{hostname_before_last_save}") if hostname_before_last_save.present?
      BetterTogether::Mcp::AllowedOrigins.reset_cache!
    end

    def host_url_uri
      URI.parse(platform.host_url.to_s)
    rescue URI::InvalidURIError
      nil
    end
  end
end
