# frozen_string_literal: true

module BetterTogether
  # Maps inbound hostnames to platforms and their canonical primary domain.
  class PlatformDomain < ApplicationRecord
    belongs_to :platform, class_name: '::BetterTogether::Platform'

    scope :active, -> { where(active: true) }
    scope :primary, -> { where(primary: true) }

    before_validation :normalize_hostname!
    validate :single_primary_domain, if: :primary?
    validate :primary_domain_must_be_active, if: :primary?

    validates :hostname, presence: true, uniqueness: { case_sensitive: false }
    validates :active, inclusion: { in: [true, false] }
    validates :primary, inclusion: { in: [true, false] }

    def self.resolve(hostname)
      active.find_by(hostname: normalize_hostname(hostname))
    end

    def self.normalize_hostname(hostname)
      hostname.to_s.strip.downcase.sub(/\.$/, '')
    end

    def url
      scheme = URI.parse(platform.host_url).scheme.presence || 'https'
      "#{scheme}://#{hostname}"
    end

    def normalize_hostname!
      self.hostname = self.class.normalize_hostname(hostname)
    end

    private

    def single_primary_domain
      return unless self.class.where(platform_id: platform_id, primary: true).where.not(id: id).exists?

      errors.add(:primary, 'has already been taken for this platform')
    end

    def primary_domain_must_be_active
      return if active?

      errors.add(:active, 'must be true for a primary domain')
    end
  end
end
