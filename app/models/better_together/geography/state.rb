module BetterTogether
  module Geography
    class State < ApplicationRecord
      include Identifier
      include Protected

      # slugged :name

      translates :name
      translates :description, type: :text

      belongs_to :country, class_name: 'BetterTogether::Geography::Country'

      validates :name, presence: true

      def to_s
        name
      end
    end
  end
end
