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

    def self.resolve(hostname)
      normalized = normalize_hostname(hostname)
      Rails.cache.fetch("bt:platform_domain:#{normalized}", expires_in: 5.minutes) do
        active.find_by(hostname: normalized)
      end
    end

    def self.normalize_hostname(hostname)
      hostname.to_s.strip.downcase.sub(/\.$/, '')
    end

    def url
      scheme = begin
        URI.parse(platform.host_url.to_s).scheme.presence
      rescue URI::InvalidURIError
        nil
      end || 'https'
      "#{scheme}://#{hostname}"
    end

    def normalize_hostname!
      self.hostname = self.class.normalize_hostname(hostname)
    end

    private

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
    end
  end
end
