# frozen_string_literal: true

module BetterTogether
  module Creatable # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      belongs_to :creator, class_name: 'BetterTogether::Person', optional: true

      scope :include_creator, -> { includes(:creator) }
    end

    class_methods do
      def extra_permitted_attributes
        super + %i[creator_id]
      end
    end
  end
end
