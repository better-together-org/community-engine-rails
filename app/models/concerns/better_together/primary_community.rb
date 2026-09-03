# frozen_string_literal: true

module BetterTogether
  module PrimaryCommunity # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      include Translatable

      def self.primary_community_delegation_attrs
        %i[name description]
      end

      class_attribute :community_class_name, default: '::BetterTogether::Community'

      translates :name, type: :string
      translates :description, backend: :action_text

      validates :name, presence: true
    end

    class_methods do
      def has_community(class_name: community_class_name, dependent: :destroy) # rubocop:todo Naming/PredicatePrefix
        self.community_class_name = class_name

        belongs_to :community, class_name: community_class_name, dependent:, autosave: true

        accepts_nested_attributes_for :community, reject_if: :blank

        before_validation :create_primary_community
        after_create :backfill_primary_community_platform
        before_destroy :clear_primary_community_platform_scoping
        after_create_commit :after_record_created
      end
    end

    def create_primary_community
      return if community.present?

      create_community(
        name:,
        description: primary_community_description,
        creator_id: (respond_to?(:creator_id) ? creator_id : nil),
        privacy: primary_community_privacy,
        **primary_community_extra_attrs
      )
    end

    # description here is rich text (ActionText) — reduce to plain text before
    # handing it off, so the auto-created Community doesn't inherit raw HTML/rich
    # formatting from whatever record is delegating its primary community to it.
    def primary_community_description
      return "#{name}'s primary community" unless respond_to?(:description)

      value = description
      value.respond_to?(:to_plain_text) ? value.to_plain_text : value
    end

    # A Platform's own primary Community — and that Community's ContactDetail,
    # built by Contactable#build_default_contact_details as part of the same
    # save, and its default Calendar, built by Community#create_default_calendar
    # as another after_create callback on the same save — always belongs to
    # that Platform. create_primary_community passes
    # bootstrapping_primary_community: true so Community#platform_presence_optional?
    # (and ContactDetail/Calendar, which delegate to it) skip
    # PlatformScoped#assign_current_platform_if_available's generic ambient
    # fallback (Current.platform / host platform / Platform.first) entirely,
    # since none of the three can reference this Platform yet — it has no id
    # until after this save. Correct all three now that this record has a
    # persisted id.
    def backfill_primary_community_platform
      return unless is_a?(BetterTogether::Platform) && community.present?

      correct_bootstrap_platform_id(community)
      correct_bootstrap_platform_id(community.contact_detail)
      community.calendars.each { |calendar| correct_bootstrap_platform_id(calendar) }
    end

    # belongs_to :community, dependent: :destroy fires *after* self is
    # destroyed (the opposite order of has_many dependent: :destroy), so
    # Platform's own row DELETE runs before community.destroy ever cascades
    # to the calendar/contact_detail/community rows that (correctly, since
    # backfill_primary_community_platform) self-reference this platform_id.
    # Postgres then rejects the platform DELETE: those rows are still
    # referencing it. Null the FK here first -- they're about to be
    # destroyed via the community cascade a moment later regardless, this
    # just avoids the ordering conflict. No-op for every other
    # has_community includer (Person), whose community is correctly scoped
    # to the ambient platform, not to itself.
    def clear_primary_community_platform_scoping
      return unless is_a?(BetterTogether::Platform) && community.present?

      community.calendars.update_all(platform_id: nil)
      clear_self_referencing_platform_id(community.contact_detail)
      clear_self_referencing_platform_id(community)
    end

    def primary_community_extra_attrs
      {}
    end

    def primary_community_privacy
      return 'private' if respond_to?(:external?) && external?
      return privacy if respond_to?(:privacy)

      'private'
    end

    # Backwards-compatible accessor used in tests and callers expecting a `primary_community` method
    def primary_community
      community
    end

    def after_record_created; end

    def to_s
      name
    end

    private

    def correct_bootstrap_platform_id(record)
      return if record.blank? || record.platform_id == id

      record.update_column(:platform_id, id)
    end

    def clear_self_referencing_platform_id(record)
      return if record.blank? || record.platform_id != id

      record.update_column(:platform_id, nil)
    end
  end
end
