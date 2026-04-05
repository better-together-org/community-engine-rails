# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Request represents a need someone wants fulfilled
    class Request < ApplicationRecord
      include Creatable
      include Exchange
      include Metrics::Viewable
      include ResponseLinkable
      include Searchable

      has_many :offers, class_name: 'BetterTogether::Joatu::Offer', through: :agreements

      categorizable class_name: '::BetterTogether::Joatu::Category'

      settings index: default_elasticsearch_index

      searchable pg_search: {
        against: %i[status urgency],
        using: {
          tsearch: {
            prefix: true,
            dictionary: 'simple'
          }
        }
      }

      # Response link associations and nested attributes
      response_linkable

      def self.permitted_attributes(id: true, destroy: false)
        super + response_link_permitted_attributes
      end

      def as_indexed_json(_options = {})
        {
          id:,
          name:,
          slug:,
          description: description.present? ? search_text_value(description) : nil,
          status:,
          urgency:
        }.compact.as_json
      end

      def after_agreement_acceptance!(offer:) # rubocop:disable Lint/UnusedMethodArgument
        nil
      end
    end
  end
end
