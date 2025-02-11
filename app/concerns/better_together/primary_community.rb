# frozen_string_literal: true

module BetterTogether
  module PrimaryCommunity # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      include Translatable

      def self.primary_community_delegation_attrs
        %i[name description]
      end

      belongs_to :community, class_name: '::BetterTogether::Community', dependent: :delete

      before_validation :create_primary_community
      after_create_commit :after_record_created

      translates :name, type: :string
      translates :description, type: :text

      validates :name, presence: true
      validates :description, presence: true
    end

    def create_primary_community
      return if community.present?

      create_community(
        name:,
        description:,
        privacy: (respond_to?(:privacy) ? privacy : 'unlisted'),
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
