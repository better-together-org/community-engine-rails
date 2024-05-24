module BetterTogether
  module PrimaryCommunity
    extend ActiveSupport::Concern

    included do
      include Translatable

      def self.primary_community_delegation_attrs
        %i[name description]
      end

      belongs_to :community, class_name: '::BetterTogether::Community', dependent: :delete

      before_validation :create_primary_community

      translates :name
      translates :description, type: :text

      validates :name, presence: true
      validates :description, presence: true
    end

    def create_primary_community
      create_community(
        name: name,
        description: description,
        privacy: (respond_to?(:privacy) ? privacy : 'secret'),
        **primary_community_extra_attrs
      )
    end

    def primary_community_extra_attrs
      {}
    end

    def to_s
      name
    end
  end
end
