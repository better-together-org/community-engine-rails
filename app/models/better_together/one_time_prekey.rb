# frozen_string_literal: true

module BetterTogether
  # A Signal Protocol one-time prekey (part of X3DH session setup).
  # One-time prekeys are consumed once when served for session initiation
  # and are never reused. The server stores only the public key.
  class OneTimePrekey < ApplicationRecord
    belongs_to :person, class_name: 'BetterTogether::Person'

    validates :key_id,     presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :public_key, presence: true
    validates :key_id,     uniqueness: { scope: :person_id }

    scope :unconsumed, -> { where(consumed: false) }
    scope :consumed,   -> { where(consumed: true) }
  end
end
