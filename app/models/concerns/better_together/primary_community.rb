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
      translates :description, type: :text

      validates :name, presence: true
    end

    class_methods do
      def has_community(class_name: community_class_name, dependent: :destroy) # rubocop:todo Naming/PredicatePrefix
        self.community_class_name = class_name

        belongs_to :community, class_name: community_class_name, dependent:, autosave: true

        accepts_nested_attributes_for :community, reject_if: :blank

        before_validation :create_primary_community
        after_create :backfill_primary_community_platform
        after_create_commit :after_record_created
      end
    end

    def create_primary_community
      return if community.present?

      create_community(
        name:,
        description: (respond_to?(:description) ? description : "#{name}'s primary community"),
        creator_id: (respond_to?(:creator_id) ? creator_id : nil),
        privacy: primary_community_privacy,
        **primary_community_extra_attrs
      )
    end

    # The very first Platform ever created has no existing platform for its own
    # primary Community — or that Community's ContactDetail, built by
    # Contactable#build_default_contact_details as part of the same save — to
    # resolve via PlatformScoped#assign_current_platform_if_available.
    # Community#bootstrapping_host_community? and
    # ContactDetail#bootstrapping_host_community_contact_detail? let both save
    # with a blank platform in exactly that one case. Backfill both platform
    # references now that this record has a persisted id. No-ops for every
    # other has_community includer (Person, subsequent Platforms), whose
    # community (and its contact_detail) already resolved their own platform
    # normally when created above.
    def backfill_primary_community_platform
      return unless is_a?(BetterTogether::Platform) && community.present?

      backfill_bootstrap_platform_id(community)
      backfill_bootstrap_platform_id(community.contact_detail)
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

    def backfill_bootstrap_platform_id(record)
      return if record.blank? || record.platform_id.present?

      record.update_column(:platform_id, id)
    end
  end
end
