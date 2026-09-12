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

    # Override: Run author and community filters before the privacy gate
    def filter_by_resource_specific_associations
      filter_by_authors
      filter_by_communities
    end

    # Override: Add privacy filtering for Posts
    def filter_by_resource_specific_status
      privacy = params[:privacy].to_s
      return @relation if privacy.blank? || privacy == 'all'

      allowed = %w[public community private]
      return @relation unless allowed.include?(privacy)

      @relation = @relation.where(privacy:)
    end

    def filter_by_communities
      return @relation unless params.key?(:community_ids)

      ids = Array(params[:community_ids]).reject(&:blank?)
      @relation = ids.empty? ? @relation.none : @relation.where(community_id: ids)
    end

    def filter_by_authors
      ids = author_filter_ids
      return @relation if ids.empty?

      @relation = @relation
                  .joins(author_join)
                  .where(author_table[:author_id].in(ids))
                  .distinct
    end

    def author_filter_ids
      Array(params[:author_ids]).reject(&:blank?)
    end

    def author_join
      main = resource_class.arel_table

      main.join(author_table, Arel::Nodes::InnerJoin)
          .on(author_join_condition(main))
          .join_sources
    end

    def author_join_condition(main)
      [
        authorable_type_condition,
        authorable_id_condition(main),
        author_type_condition,
        author_role_condition
      ].reduce { |memo, node| memo.and(node) }
    end

    def authorable_type_condition
      author_table[:authorable_type].eq(resource_class.name)
    end

    def authorable_id_condition(main)
      author_table[:authorable_id].eq(main[:id])
    end

    def author_type_condition
      author_table[:author_type].eq('BetterTogether::Person')
    end

    def author_role_condition
      author_table[:role].eq(::BetterTogether::Authorship::AUTHOR_ROLE)
    end

    def author_table
      ::BetterTogether::Authorship.arel_table
    end

    # Override: Default ordering for Posts is newest-first (created_at desc)
    def default_order_by
      @relation.reorder(created_at: :desc)
    end
  end
end
