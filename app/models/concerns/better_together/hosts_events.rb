# frozen_string_literal: true

module BetterTogether
  # Concern that when included gives the model access to events through event_host records
  # This module must be included in a model to permit assigning instances as an event host
  module HostsEvents
    extend ActiveSupport::Concern

    included do
      has_many :event_hosts, as: :host
      has_many :hosted_events, through: :event_hosts, source: :event
    end

    def self.included_in_models
      included_module = self
      Rails.application.eager_load! if Rails.env.development? # Ensure all models are loaded
      ActiveRecord::Base.descendants.select { |model| model.included_modules.include?(included_module) }
    end
  end
end
