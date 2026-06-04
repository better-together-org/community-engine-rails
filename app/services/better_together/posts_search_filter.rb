# frozen_string_literal: true

module BetterTogether
  # Search and filter service for Posts index.
  # Filters by text (ILIKE title + content), category, privacy, order, and paginates.
  # Inherits common search logic from ContentSearchFilter.
  class PostsSearchFilter < ContentSearchFilter
    def self.call(relation:, params:)
      new(resource_class: BetterTogether::Post, relation:, params:).call
    end

    private

    # Override: Posts use 'content' as the ActionText field name
    def action_text_field
      'content'
    end

    # Override: Add privacy filtering for Posts
    def filter_by_resource_specific_status
      privacy = params[:privacy].to_s
      return @relation if privacy.blank? || privacy == 'all'

      allowed = %w[public community private]
      return @relation unless allowed.include?(privacy)

      @relation = @relation.where(privacy:)
    end

    # Override: Default ordering for Posts is newest-first (created_at desc)
    def default_order_by
      @relation.reorder(created_at: :desc)
    end
  end
end
