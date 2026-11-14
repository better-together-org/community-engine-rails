# frozen_string_literal: true

module BetterTogether
  # Concern for models that can be the target of a BetterTogether::Report (Safety pipeline).
  module Reportable
    extend ActiveSupport::Concern

    included do
      # No dependent: option deliberately — Report/Safety::Case are the moderation audit
      # trail and must survive the reported record being deleted. Person overrides this
      # with dependent: :destroy to preserve its own pre-existing behavior; every other
      # includer keeps this default.
      has_many :reports_received, as: :reportable, class_name: 'BetterTogether::Report'
    end

    # Dynamic extension point: a host app opts a model into the safety/Report pipeline
    # solely by including this concern — no gem-owned allow-list to edit. See
    # docs/developers/architecture/polymorphic_allowlist_extension_audit.md
    def self.included_in_models
      included_module = self
      Rails.application.eager_load! unless Rails.env.production?
      ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
    end
  end
end
