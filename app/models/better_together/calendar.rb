# frozen_string_literal: true

module BetterTogether
  # Calendar management and display
  class Calendar < PlatformRecord
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

    # Every primary community (the bootstrapping host community, and every
    # subsequent platform's own primary community) creates its own default
    # calendar via Community's after_create :create_default_calendar
    # callback, which fires before PrimaryCommunity#backfill_primary_community_platform
    # has a platform to backfill (see Community#bootstrapping_host_community?
    # / #bootstrapping_primary_community). Overrides
    # PlatformScoped#platform_presence_optional? the same way Community and
    # ContactDetail do for the same underlying bootstrap ordering problem.
    def platform_presence_optional?
      return false unless community

      community.bootstrapping_host_community? || community.bootstrapping_primary_community
    end
  end
end
