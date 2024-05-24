# frozen_string_literal: true

module BetterTogether
  # Concern that when included makes the model act as an identity
  module PrimaryCommunity
    extend ActiveSupport::Concern

    included do
      include Translatable

      def self.primary_community_delegation_attrs
        %i[name description]
      end

      belongs_to :community, class_name: '::BetterTogether::Community', dependent: :delete

      before_create :create_primary_community

      translates :name
      translates :description, type: :text

      # delegate *self.primary_community_delegation_attrs, to: :community

      validates :name, presence: true
      validates :description, presence: true
    end

    # Method to build the primary community
    def create_primary_community
      # Build the associated community with matching attributes
      # byebug
      create_community(name:, description:, privacy: (respond_to?(:privacy) ? privacy : 'secret'),
                       **primary_community_extra_attrs)
    end

    def primary_community_extra_attrs
      {}
    end

    def to_s
      name
    end
  end
end
