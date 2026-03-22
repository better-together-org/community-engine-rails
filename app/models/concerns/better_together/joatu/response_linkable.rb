# frozen_string_literal: true

module BetterTogether
  module Joatu
    module ResponseLinkable # rubocop:todo Style/Documentation
      extend ActiveSupport::Concern

      class_methods do
        # Call this in a model to add the standardized response_link associations
        # and nested attributes. Example: call `response_linkable` in Offer and Request models.
        def response_linkable
          has_many :response_links_as_source, class_name: 'BetterTogether::Joatu::ResponseLink', as: :source,
                                              dependent: :nullify
          has_many :response_links_as_response, class_name: 'BetterTogether::Joatu::ResponseLink', as: :response,
                                                dependent: :nullify

          accepts_nested_attributes_for :response_links_as_source, :response_links_as_response, allow_destroy: true
        end

        # Helper to provide the nested attributes for strong params
        def response_link_permitted_attributes
          [
            { response_links_as_response_attributes: BetterTogether::Joatu::ResponseLink.permitted_attributes },
            { response_links_as_source_attributes: BetterTogether::Joatu::ResponseLink.permitted_attributes }
          ]
        end
      end
    end
  end
end
