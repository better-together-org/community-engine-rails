# frozen_string_literal: true

module BetterTogether
  # Represents a class that has control over the actions of other classes.
  # Meant to be used with user login classes
  module Agent
    extend ActiveSupport::Concern

    included do
      has_many :identifications,
               as: :agent

      # def active_identity
      # identification = identifications.find_by(active: true) ||
      #                  identifications.first

      # return unless identification

      # identification.identity
      # end
    end
  end
end
