# frozen_string_literal: true

module BetterTogether
  # Form to set the main attributes of the host platform during the setup wizard
  class HostPlatformDetailsForm < ::Reform::Form
    MODEL_CLASS = ::BetterTogether::Platform
    model :platform, namespace: :better_together

    property :name
    property :description
    property :host_url
    property :privacy
    property :time_zone
  end
end
