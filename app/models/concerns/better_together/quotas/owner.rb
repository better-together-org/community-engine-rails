# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Concern for models that can hold a BetterTogether::Quota (Person, Community,
    # Platform today). Dynamic extension point, same pattern as Commentable: a model
    # becomes a valid quota owner purely by including this concern, not via a
    # gem-owned hardcoded allow-list. See
    # docs/developers/architecture/polymorphic_allowlist_extension_audit.md
    module Owner
      extend ActiveSupport::Concern

      included do
        has_many :quotas, as: :owner, class_name: 'BetterTogether::Quota', dependent: :destroy
      end

      def self.included_in_models
        included_module = self
        Rails.application.eager_load! unless Rails.env.production?
        ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
      end
    end
  end
end
