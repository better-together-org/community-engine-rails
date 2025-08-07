# frozen_string_literal: true

module BetterTogether
  # Access control for posts
  class PostPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      (record.published? && record.privacy_public?) || record.creator == agent || permitted_to?('manage_platform')
    end

    def create?
      permitted_to?('manage_platform')
    end
    alias new? create?

    def update?
      permitted_to?('manage_platform')
    end
    alias edit? update?

    def destroy?
      permitted_to?('manage_platform')
    end

    # Scope for resolving visible posts
    class Scope < ApplicationPolicy::Scope
      # rubocop:disable Metrics/AbcSize
      def resolve
        return scope.all if permitted_to?('manage_platform')

        base = scope.published
        public_posts = posts_table[:privacy].eq('public')
        return base.where(public_posts) unless agent

        creator_posts = posts_table[:creator_id].eq(agent.id)
        base.where(public_posts.or(creator_posts))
      end
      # rubocop:enable Metrics/AbcSize

      private

      def posts_table
        ::BetterTogether::Post.arel_table
      end
    end
  end
end
