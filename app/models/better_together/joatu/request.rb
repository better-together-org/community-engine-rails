# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Request represents a need someone wants fulfilled
    class Request < ApplicationRecord
      include Creatable
      include Exchange
      include Metrics::Viewable

      has_many :offers, class_name: 'BetterTogether::Joatu::Offer', through: :agreements

      categorizable class_name: '::BetterTogether::Joatu::Category'

      # Response links where this Request is the source (Request -> Offer)
      has_many :response_links_as_source, class_name: 'BetterTogether::Joatu::ResponseLink', as: :source,
                                          dependent: :nullify

      # Response links where this Request is the response (Offer -> Request)
      has_many :response_links_as_response, class_name: 'BetterTogether::Joatu::ResponseLink', as: :response,
                                            dependent: :nullify

      accepts_nested_attributes_for :response_links_as_source, :response_links_as_response, allow_destroy: true

      def self.permitted_attributes(id: true, destroy: false)
        super + [
          { response_links_as_response_attributes: BetterTogether::Joatu::ResponseLink.permitted_attributes },
          { response_links_as_source_attributes: BetterTogether::Joatu::ResponseLink.permitted_attributes }
        ]
      end
    end
  end
end
