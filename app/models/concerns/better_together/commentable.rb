# frozen_string_literal: true

module BetterTogether
  # Concern for models that can receive BetterTogether::Comment records.
  module Commentable
    extend ActiveSupport::Concern

    included do
      has_many :comments, as: :commentable, class_name: 'BetterTogether::Comment', dependent: :destroy
    end

    # Dynamic extension point: a host app opts a model into comments solely by including
    # this concern — no gem-owned allow-list to edit. See
    # docs/developers/architecture/polymorphic_allowlist_extension_audit.md
    def self.included_in_models
      included_module = self
      Rails.application.eager_load! unless Rails.env.production?
      ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
    end
  end
end
