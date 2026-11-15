# frozen_string_literal: true

module BetterTogether
  # Computes the visibility ceiling imposed on a record by its wrapping
  # platform and community. It never blocks a save: content can be prepared as
  # public behind a private platform and goes live when the platform opens.
  #
  # Ceiling rules (most to least restrictive: private, community, public):
  #   - Platform public + community public     => ceiling = 'public'
  #   - Platform public + community non-public => ceiling = 'community'
  #   - Platform non-public                    => ceiling = 'community'
  #
  # `effective_privacy` is the more restrictive of the record's own privacy and
  # the ceiling. Readers (policies, scopes, sitemaps, media, federation export)
  # must use it, or the SQL twin `within_privacy_ceiling`, instead of `privacy`.
  module PrivacyCeilingValidatable
    extend ActiveSupport::Concern

    CEILING_ORDER = %w[private community public].freeze

    # Ceiling for an explicit platform/community pair (nil means unbounded).
    def self.ceiling_for(platform: nil, community: nil)
      return nil unless platform || community

      [platform, community].compact.all?(&:privacy_public?) ? 'public' : 'community'
    end

    # Builds the SQL twin of #privacy_ceiling for a model's table.
    module SqlPredicate
      def self.open_arel(model, table)
        columns = model.privacy_ceiling_wrapper_columns
        return Arel::Nodes::True.new if columns.empty?

        open = columns.map { |column| wrapper_open(table, column) }.reduce { |memo, node| memo.and(node) }
        mirrored = mirrored_arel(model, table)
        mirrored ? open.or(mirrored) : open
      end

      def self.wrapper_open(table, column)
        wrapper = column == 'platform_id' ? BetterTogether::Platform : BetterTogether::Community
        open_ids = wrapper.where(privacy: 'public')
        open_ids = open_ids.or(wrapper.where(external: true)) if wrapper == BetterTogether::Platform
        table[column.to_sym].eq(nil).or(table[column.to_sym].in(open_ids.select(:id).arel))
      end

      # Federated mirrors carry the origin's already-vetted privacy.
      def self.mirrored_arel(model, table)
        names = %w[source_id last_synced_at].select { |name| model.column_names.include?(name) }
        names.map { |name| table[name.to_sym].not_eq(nil) }.reduce { |memo, node| memo.or(node) }
      end
    end

    class_methods do
      # Foreign keys whose rows can cap visibility. Models that never carry a
      # ceiling (see Agreement, Category, Platform) override this with [].
      # A record's own primary community (PrimaryCommunity#has_community: Person,
      # Building, Room, geography and similar) is its identity community, not a
      # container, so it never caps the record.
      def privacy_ceiling_wrapper_columns
        columns = %w[platform_id community_id] & column_names
        columns -= ['community_id'] if include?(BetterTogether::PrimaryCommunity)
        columns
      end

      # Arel predicate true for rows whose ceiling still allows 'public'.
      def privacy_ceiling_open_arel(table = arel_table)
        SqlPredicate.open_arel(self, table)
      end

      def within_privacy_ceiling
        where(privacy_ceiling_open_arel)
      end
    end

    # The most open privacy this record may effectively have, or nil if unbounded.
    def privacy_ceiling
      return nil if privacy_ceiling_exempt?

      wrapping_platform = wrapping_privacy_ceiling_platform
      return nil if external_wrapping_platform?(wrapping_platform)

      PrivacyCeilingValidatable.ceiling_for(platform: wrapping_platform, community: wrapping_privacy_ceiling_community)
    end

    # The more restrictive of the record's own privacy and its ceiling.
    def effective_privacy
      own = privacy.to_s
      max = privacy_ceiling
      return own if max.nil?

      own_idx = CEILING_ORDER.index(own)
      return own if own_idx.nil?

      CEILING_ORDER[[own_idx, CEILING_ORDER.index(max)].min]
    end

    # True when the platform or community currently hides more than the record asks for.
    def privacy_capped?
      privacy.present? && effective_privacy != privacy.to_s
    end

    def effective_privacy_public?
      effective_privacy == 'public'
    end

    def effective_privacy_community?
      effective_privacy == 'community'
    end

    # Models whose `privacy` is not used for visibility gating (Agreement,
    # Category) return true. Federated mirrors carry the origin's privacy.
    def privacy_ceiling_exempt?
      respond_to?(:mirrored?) && mirrored?
    end

    private

    def wrapping_privacy_ceiling_platform
      respond_to?(:platform) ? platform : nil
    end

    def wrapping_privacy_ceiling_community
      return nil if self.class.include?(BetterTogether::PrimaryCommunity)

      respond_to?(:community) ? community : nil
    end

    # External platforms (federation peers, identity providers) are registry
    # entries, not local visibility containers, so no ceiling applies.
    def external_wrapping_platform?(wrapping_platform)
      wrapping_platform.respond_to?(:external?) && wrapping_platform.external?
    end
  end
end
