# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Offer represents a service or item someone is willing to provide
    class Offer < ApplicationRecord
      include Creatable
      include Exchange
      include Metrics::Viewable
      include ResponseLinkable

      has_many :requests, class_name: 'BetterTogether::Joatu::Request', through: :agreements

      categorizable class_name: '::BetterTogether::Joatu::Category'

      # Response link associations and nested attributes
      response_linkable

      def self.permitted_attributes(id: true, destroy: false)
        super + response_link_permitted_attributes
      end
    end
  end
end
