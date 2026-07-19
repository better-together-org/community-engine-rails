# frozen_string_literal: true

module BetterTogether
  # Form to set a new tenant platform's identity attributes during the
  # new_platform_setup wizard's platform_identity step.
  class NewPlatformIdentityForm < ::Reform::Form
    MODEL_CLASS = ::BetterTogether::Platform
    model :platform, namespace: :better_together

    property :name
    property :description
    property :host_url
    property :privacy
    property :time_zone
  end
end
