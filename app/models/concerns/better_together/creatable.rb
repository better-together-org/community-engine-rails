module BetterTogether
  module Creatable
    extend ActiveSupport::Concern

    included do
      belongs_to :creator, class_name: 'BetterTogether::Person'

      scope :include_creator, -> { includes(:creator) }
    end

    class_methods do
      def extra_permitted_attributes
        super + %i[creator_id]
      end
    end
  end
end
