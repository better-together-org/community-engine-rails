# frozen_string_literal: true

module BetterTogether
  # Concern that when included gives the model access to events through event_host records
  module HostsEvents
    extend ActiveSupport::Concern

    included do
      has_many :event_hosts, as: :host
      has_many :hosted_events, through: :event_hosts, source: :event
    end
  end
end
