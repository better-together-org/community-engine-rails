# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a collection of BetterTogether::Event records
    class EventsBlock < Block
      include ::BetterTogether::Content::ResourceBlockAttributes

      EVENT_SCOPES = %w[upcoming recent all].freeze

      store_attributes :content_data do
        event_scope String, default: 'upcoming'
      end

      validates :event_scope, inclusion: { in: EVENT_SCOPES }

      def self.content_addable?
        true
      end

      def self.extra_permitted_attributes
        super + %i[event_scope]
      end
    end
  end
end
