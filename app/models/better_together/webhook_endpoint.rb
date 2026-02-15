# frozen_string_literal: true

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
    def self.permitted_attributes
      %i[url name description events active oauth_application_id]
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
  end
end
