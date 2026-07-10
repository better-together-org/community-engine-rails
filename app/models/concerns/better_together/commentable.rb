# frozen_string_literal: true

module BetterTogether
  # Concern for models that can receive BetterTogether::Comment records.
  module Commentable
    extend ActiveSupport::Concern

    included do
      has_many :comments, as: :commentable, class_name: 'BetterTogether::Comment', dependent: :destroy
      has_one :comment_config, as: :commentable, class_name: 'BetterTogether::CommentConfig', dependent: :destroy
      accepts_nested_attributes_for :comment_config
    end

    # Lazy reads: every comment-creation/visibility check reads these, so the default
    # ('inherit', today's behavior) must be answerable without a CommentConfig row
    # existing — unlike Recurrence/RecurringSchedulable, where absence just means "not
    # recurring" and callers check `.recurrence&.rule` directly.
    def comment_permission
      comment_config&.permission || 'inherit'
    end

    def comment_permission=(value)
      (comment_config || build_comment_config).permission = value
    end

    def comment_visibility
      comment_config&.visibility || 'inherit'
    end

    def comment_visibility=(value)
      (comment_config || build_comment_config).visibility = value
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
