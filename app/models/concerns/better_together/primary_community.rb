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
      def has_community(class_name: community_class_name) # rubocop:todo Naming/PredicateName
        self.community_class_name = class_name

        belongs_to :community, class_name: community_class_name, dependent: :destroy

        before_validation :create_primary_community
        after_create_commit :after_record_created
      end
    end

    def create_primary_community
      return if community.present?

      create_community(
        name:,
        description:,
        creator_id: (respond_to?(:creator_id) ? creator_id : nil),
        privacy: (respond_to?(:privacy) ? privacy : 'private'),
        **primary_community_extra_attrs
      )
    end

    def primary_community_extra_attrs
      {}
    end

    def after_record_created; end

    def to_s
      name
    end
  end
end
