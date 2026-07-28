# frozen_string_literal: true

module BetterTogether
  # Calendar management and display
  class Calendar < PlatformRecord
    include Citable
    include Claimable
    include Creatable
    include FriendlySlug
    include Identifier
    include Privacy
    include Protected
    include Viewable

    belongs_to :community, class_name: '::BetterTogether::Community'

    has_many :calendar_entries, class_name: 'BetterTogether::CalendarEntry', dependent: :destroy
    has_many :events, through: :calendar_entries

    # Secure token for calendar feed subscriptions (iCal, JSON)
    # Uses Rails' has_secure_token for cryptographically strong token generation
    # Encrypted at rest because tokens grant access to private calendar data
    has_secure_token :subscription_token
    encrypts :subscription_token

    slugged :name

    translates :name, type: :string
    translates :description, backend: :action_text

    def to_s
      name
    end

    # The bootstrapping host community creates its own default calendar via
    # Community's after_create :create_default_calendar callback, which fires
    # before PrimaryCommunity#backfill_primary_community_platform has a
    # platform to backfill (the platform itself doesn't exist yet — see
    # Community#bootstrapping_host_community?). Overrides
    # PlatformScoped#platform_presence_optional? the same way Community and
    # ContactDetail do for the same underlying bootstrap ordering problem.
    def platform_presence_optional?
      community&.bootstrapping_host_community? || false
    end
  end
end
