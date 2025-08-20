# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Request represents a need someone wants fulfilled
    class Request < ApplicationRecord
      include Creatable
      include Exchange
      include Metrics::Viewable
      include ResponseLinkable

      has_many :offers, class_name: 'BetterTogether::Joatu::Offer', through: :agreements

      categorizable class_name: '::BetterTogether::Joatu::Category'

      # Response link associations and nested attributes
      response_linkable

      def self.permitted_attributes(id: true, destroy: false)
        super + response_link_permitted_attributes
      end
    end
  end
end
