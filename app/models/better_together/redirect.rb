# frozen_string_literal: true

module BetterTogether
  # A platform-scoped redirect (or gone response) for a request path.
  #
  # Matching is on the normalized path (decoded, leading slash, no trailing slash),
  # case-insensitively, and only on the platform the request resolved to, so two
  # platforms can both define `/about`. Resolution happens in RedirectMiddleware,
  # before routing and the pages catch-all.
  class Redirect < ApplicationRecord
    STATUSES = [301, 302, 307, 308, 410].freeze
    SOURCES = %w[manual import seed slug_history].freeze
    # Natural key and writable attributes, for registration with a seed registry.
    SEED_KEY = %i[platform_id from_path].freeze
    SEED_ATTRIBUTES = %i[to_path status active preserve_query source note].freeze
    MAX_CHAIN = 10

    belongs_to :platform, class_name: '::BetterTogether::Platform'

    scope :active, -> { where(active: true) }

    before_validation :normalize_paths

    validates :from_path, presence: true, uniqueness: { scope: :platform_id, case_sensitive: false }
    validates :status, inclusion: { in: STATUSES }
    validates :source, inclusion: { in: SOURCES }
    validates :to_path, presence: true, unless: :gone?
    validate :to_path_is_safe, if: -> { to_path.present? && !gone? }
    validate :not_a_loop, if: -> { to_path.present? && !gone? }

    after_commit :bust_cache

    def self.normalize_path(value)
      path = value.to_s.strip.split(/[?#]/, 2).first.to_s
      path = begin
        Rack::Utils.unescape_path(path)
      rescue ArgumentError
        path
      end
      path = "/#{path}" unless path.start_with?('/')
      path = path.squeeze('/')
      path.length > 1 ? path.chomp('/') : path
    end

    def self.cache_key_for(platform_id)
      "bt:redirects:#{platform_id}"
    end

    def gone?
      status == 410
    end

    def external?
      to_path.to_s.match?(%r{\Ahttps?://}i)
    end

    private

    def normalize_paths # rubocop:disable Metrics/AbcSize
      self.from_path = self.class.normalize_path(from_path) if from_path.present?
      return if to_path.blank?

      self.to_path = to_path.strip
      self.to_path = self.class.normalize_path(to_path) if site_path? && to_path.exclude?('?')
    end

    def site_path?
      to_path.start_with?('/') && !to_path.start_with?('//')
    end

    def to_path_is_safe
      return if external? && valid_http_uri?
      return if site_path?

      errors.add(:to_path, :invalid)
    end

    def valid_http_uri?
      uri = URI.parse(to_path)
      uri.host.present? && %w[http https].include?(uri.scheme)
    rescue URI::InvalidURIError
      false
    end

    # Follows the chain of redirects on this platform; the new row must not lead back to itself.
    def not_a_loop # rubocop:disable Metrics/AbcSize
      seen = [from_path.to_s.downcase]
      current = to_path
      MAX_CHAIN.times do
        return if current.blank? || current.match?(%r{\Ahttps?://}i)

        key = self.class.normalize_path(current).downcase
        if seen.include?(key)
          errors.add(:to_path, :redirect_loop)
          return
        end
        seen << key
        nxt = self.class.active.where(platform_id:).where.not(id:).find_by(self.class.arel_table[:from_path].lower.eq(key))
        return unless nxt && !nxt.gone?

        current = nxt.to_path
      end
    end

    def bust_cache
      Rails.cache.delete(self.class.cache_key_for(platform_id))
    end
  end
end
