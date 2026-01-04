# frozen_string_literal: true

module BetterTogether
  # Access control for posts
  class PostPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      # Always allow creator and platform managers
      return true if record.creator == agent || permitted_to?('manage_platform')

      # Deny if author is blocked
      return false if blocked_author?

      # Allow if published and public
      record.published? && record.privacy_public?
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

    private

    def post_author_ids
      @post_author_ids ||= if record.authorships.loaded?
                             record.authorships.map(&:author_id)
                           else
                             record.authorships.pluck(:author_id)
                           end
    end

    def blocked_author?
      return false unless agent

      # Check both authorships and creator
      author_ids = post_author_ids
      author_ids << record.creator_id if record.creator_id

      blocked_ids = blocked_person_ids_for_agent
      author_ids.intersect?(blocked_ids)
    end

    def blocked_person_ids_for_agent
      @blocked_person_ids_for_agent ||= agent.blocked_people.pluck(:id)
    end
  end
end
