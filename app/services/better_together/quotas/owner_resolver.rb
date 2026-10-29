# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Resolves the BetterTogether::Quotas::Owner (Person, Community, or Platform) a
    # given record's usage should be charged to. A duck-typed, ordered chain rather
    # than per-model-class branching; see the quota framework plan's "Resolver"
    # section for the full rationale of each step.
    module OwnerResolver
      # Models with no Platform fallback of their own (ApplicationRecord, not
      # PlatformRecord, so platform_owner below never short-circuits this) that need
      # one additional named hop before the usual creator/community/platform chain
      # can apply. Small and enumerated from a direct inventory of the engine's
      # attachment-bearing models, not an open-ended/recursive walk. Message was
      # considered but is PlatformRecord (has its own platform fallback already),
      # so it needs no entry here.
      NAMED_HOPS = {
        'BetterTogether::PlatformInvitation' => :inviter,
        'BetterTogether::EventOccurrence' => :event
      }.freeze

      # Method names tried, in order, as a "creator-equivalent" owner for a record:
      # :creator covers the Creatable concern; :initiator covers Ai::Log::Translation,
      # which uses that name for the same role.
      CREATOR_LIKE_METHODS = %i[creator initiator].freeze

      module_function

      def resolve(record)
        record = BetterTogether::ActiveStorageAttachmentRecord.resolve(record)
        return platform_fallback if record.nil?
        return record if owner_record?(record)

        creator_like_owner(record) ||
          community_owner(record) ||
          platform_owner(record) ||
          hopped_owner(record) ||
          platform_fallback
      end

      def owner_record?(record)
        BetterTogether::Quotas::Owner.included_in_models.any? { |klass| record.is_a?(klass) }
      end

      def creator_like_owner(record)
        CREATOR_LIKE_METHODS.each do |method_name|
          next unless record.respond_to?(method_name)

          value = record.public_send(method_name)
          return value if value.present?
        end
        nil
      end

      def community_owner(record)
        return nil unless record.respond_to?(:community)

        record.community.presence
      end

      def platform_owner(record)
        return nil unless record.respond_to?(:platform)

        record.platform.presence
      end

      def hopped_owner(record)
        method_name = NAMED_HOPS[record.class.name]
        return nil unless method_name && record.respond_to?(method_name)

        hop_target = record.public_send(method_name)
        hop_target.present? ? resolve(hop_target) : nil
      end

      def platform_fallback
        BetterTogether::Platform.find_by(host: true) || BetterTogether::Platform.first
      end
    end
  end
end
