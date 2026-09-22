# frozen_string_literal: true

module BetterTogether
  # Reverse associations for person-authored communications.
  module Communicator
    extend ActiveSupport::Concern

    included do
      has_many :sent_messages,
               foreign_key: :sender_id,
               class_name: 'BetterTogether::Message',
               inverse_of: :sender
    end
  end
end
