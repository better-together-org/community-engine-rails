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

    # The one case that can't resolve a platform yet: the very first Platform's
    # own host Community builds its default calendar (see
    # Community#create_default_calendar, an after_create callback) before that
    # platform exists — same bootstrapping window as
    # ContactDetail#platform_presence_optional?. Overrides
    # PlatformScoped#platform_presence_optional?; backfilled once the platform
    # is persisted by PrimaryCommunity#backfill_primary_community_platform.
    def platform_presence_optional?
      community&.bootstrapping_host_community? || false
    end

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
  end
end
