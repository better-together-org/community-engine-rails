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
        after_create :create_deferred_primary_community
        after_create_commit :after_record_created
      end
    end

    def create_primary_community
      return if community.present?
      # The very first Platform ever created has no existing platform for its own
      # primary Community (and that Community's ContactDetail) to resolve via
      # PlatformScoped#assign_current_platform_if_available — Community/ContactDetail
      # require a platform, but this platform doesn't have a persisted id yet, and no
      # other platform exists to fall back to. Defer to create_deferred_primary_community,
      # which runs after this record is persisted and can reference itself.
      return if bootstrapping_first_platform?

      create_community(
        name:,
        description: (respond_to?(:description) ? description : "#{name}'s primary community"),
        creator_id: (respond_to?(:creator_id) ? creator_id : nil),
        privacy: primary_community_privacy,
        **primary_community_extra_attrs
      )
    end

    # Handles the one case create_primary_community defers: this record's own
    # primary community, when this is the very first Platform in the database.
    # No-ops for every other has_community includer (Person, subsequent Platforms)
    # since their community is already created via the synchronous path above.
    def create_deferred_primary_community
      return if community.present?
      return unless is_a?(BetterTogether::Platform)

      new_community = community_class_name.constantize.create!(
        name:,
        description: (respond_to?(:description) ? description : "#{name}'s primary community"),
        creator_id: (respond_to?(:creator_id) ? creator_id : nil),
        privacy: primary_community_privacy,
        platform: self,
        **primary_community_extra_attrs
      )
      update_column(:community_id, new_community.id)
    end

    def bootstrapping_first_platform?
      is_a?(BetterTogether::Platform) && !BetterTogether::Platform.exists?
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
  end
end
