# frozen_string_literal: true

require 'ipaddr'
require 'resolv'

module BetterTogether
  # Represents a registered webhook endpoint that receives event notifications
  # from the platform. Each endpoint is owned by a person and optionally linked
  # to an OAuth application.
  #
  # Endpoints filter events using the `events` array — an empty array means
  # all events are delivered.
  #
  # Outbound payloads are signed with HMAC-SHA256 using the endpoint's `secret`.
  class WebhookEndpoint < ApplicationRecord
    self.table_name = 'better_together_webhook_endpoints'

    VALID_EVENT_PATTERN = /\A[a-z_]+\.[a-z_]+\z/

    PRIVATE_IP_RANGES = [
      IPAddr.new('127.0.0.0/8'),
      IPAddr.new('10.0.0.0/8'),
      IPAddr.new('172.16.0.0/12'),
      IPAddr.new('192.168.0.0/16'),
      IPAddr.new('169.254.0.0/16'),
      IPAddr.new('0.0.0.0/8'),
      IPAddr.new('::1/128'),
      IPAddr.new('fc00::/7'),
      IPAddr.new('fe80::/10')
    ].freeze

    belongs_to :person,
               class_name: 'BetterTogether::Person'

    belongs_to :oauth_application,
               class_name: 'BetterTogether::OauthApplication',
               optional: true

    has_many :webhook_deliveries,
             class_name: 'BetterTogether::WebhookDelivery',
             dependent: :destroy

    validates :url, presence: true,
                    format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                              message: :invalid_url }
    validates :secret, presence: true
    validates :name, presence: true
    validate :validate_event_names
    validate :validate_url_target_is_public

    before_validation :generate_secret, on: :create, if: -> { secret.blank? }

    scope :active, -> { where(active: true) }
    scope :for_event, lambda { |event|
      active.where('events = :empty OR :event = ANY(events)', empty: '{}', event: event)
    }

    # Check whether this endpoint should receive the given event
    # @param event [String] event name like "community.created"
    # @return [Boolean]
    def subscribed_to?(event)
      events.empty? || events.include?(event)
    end

    # Permitted attributes for strong parameters
    # @return [Array<Symbol>]
    def self.permitted_attributes(id: false, destroy: false)
      super + %i[url name description events active oauth_application_id]
    end

    # By default, only allow public webhook targets in production.
    # Development/test often need localhost targets for validating delivery.
    def self.allow_private_targets?
      Rails.env.development? || Rails.env.test? || ENV.fetch('ALLOW_PRIVATE_WEBHOOK_ENDPOINTS', 'false') == 'true'
    end

    private

    def generate_secret
      self.secret = SecureRandom.hex(32)
    end

    def validate_event_names
      return if events.blank?

      events.each do |event|
        unless event.match?(VALID_EVENT_PATTERN)
          errors.add(:events, "contains invalid event name: #{event}")
        end
      end
    end

    def validate_url_target_is_public
      return if self.class.allow_private_targets?

      ip_addrs = webhook_target_ip_addrs
      return if ip_addrs.empty?
      return unless ip_addrs.any? { |ip| private_or_local_ip?(ip) }

      errors.add(:url, :invalid_url)
    end

    def webhook_target_ip_addrs
      return [] if url.blank?

      uri = URI.parse(url)
      return [] if uri.host.blank?

      resolved_ip_addrs_for(uri.host)
    rescue URI::InvalidURIError
      []
    end

    def resolved_ip_addrs_for(host)
      # If host is already an IP literal, keep it as-is.
      return [host] if ip_literal?(host)

      Resolv.getaddresses(host)
    rescue Resolv::ResolvError
      []
    end

    def ip_literal?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::InvalidAddressError
      false
    end

    def private_or_local_ip?(ip_string)
      ip = IPAddr.new(ip_string)

      PRIVATE_IP_RANGES.any? { |r| r.include?(ip) }
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end
