# frozen_string_literal: true

module BetterTogether
  # Used to invite someone to something (platform, community, etc)
  class Invitation < ApplicationRecord
    belongs_to :invitable,
               polymorphic: true
    belongs_to :inviter,
               polymorphic: true
    belongs_to :invitee,
               polymorphic: true
    belongs_to :role,
               optional: true

    enum status: {
      accepted: 'accepted',
      declined: 'declined',
      pending: 'pending'
    }
  end
end
