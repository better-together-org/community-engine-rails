# frozen_string_literal: true

module BetterTogether
  # Access control for posts
  class PostPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      # Always allow the creator and platform stewards
      return true if creator_or_platform_steward? || community_content_manager?

      # Deny if author is blocked
      return false if blocked_author?

      # Community visibility is limited to members of the platform's primary community.
      record.published? && public_or_member_scoped_community?(record)
    end

    def create?
      platform_content_manager? || community_content_manager?
    end
    alias new? create?

    def update?
      creator_platform_steward_or_editor? || community_content_manager?
    end
    alias edit? update?

    def destroy?
      creator_or_platform_steward? || community_content_manager?
    end

    # Scope for resolving visible posts
    class Scope < ApplicationPolicy::Scope
      # rubocop:disable Metrics/AbcSize
      def resolve
        base = scope.latest_first
        posts = posts_table

        return base.where(posts[:community_id].in(platform_community_ids)) if platform_content_manager?
        return base.where(posts[:community_id].in(managed_community_ids)) if agent.present? && managed_community_ids.any?

        base = base.published
        base = base.excluding_blocked_for(agent) if agent
        visible_posts = visible_privacy_query(posts)
        community_filter = posts[:community_id].in(accessible_community_ids)
        visible_scoped = visible_posts.and(community_filter)
        return base.where(visible_scoped) unless agent

        creator_posts = posts[:creator_id].eq(agent.id).and(community_filter)
        base.where(visible_scoped.or(creator_posts))
      end
      # rubocop:enable Metrics/AbcSize

      private

      def posts_table
        ::BetterTogether::Post.arel_table
      end

      def platform_content_manager?
        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
      end

      def managed_community_ids
        return [] unless agent.present?

        BetterTogether::PersonCommunityMembership
          .joins(role: { role_resource_permissions: :resource_permission })
          .where(member_id: agent.id, status: 'active',
                 better_together_resource_permissions: { identifier: 'manage_community_content' })
          .distinct
          .pluck(:joinable_id)
      end

      def accessible_community_ids
        community_scope = BetterTogether::CommunityPolicy::Scope
                          .new(user, BetterTogether::Community, invitation_token: invitation_token)
                          .resolve

        if community_scope.none?
          community_scope = BetterTogether::Community.where(privacy: 'public')
        end

        community_scope.select(:id)
      end

      def platform_community_ids
        BetterTogether::Community.all.select(:id)
      end
    end

    private

    def platform_content_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end

    def community_content_manager?
      target_community = if record.is_a?(Class)
                           Current.platform&.community
                         else
                           record.community || record.platform&.community
                         end
      return false unless target_community

      permitted_to?('manage_community_content', target_community)
    end

    def creator_or_platform_steward?
      record.creator == agent || platform_content_manager?
    end

    def creator_platform_steward_or_editor?
      creator_or_platform_steward? || (agent.present? && record.editable_contributors.include?(agent))
    end

    def post_author_ids
      @post_author_ids ||= if record.authorships.loaded?
                             record.authorships.select do |authorship|
                               authorship.author_type == 'BetterTogether::Person' &&
                                 authorship.role == BetterTogether::Authorship::AUTHOR_ROLE
                             end
                                               .map(&:author_id)
                           else
                             record.authorships.where(author_type: 'BetterTogether::Person',
                                                      role: BetterTogether::Authorship::AUTHOR_ROLE).pluck(:author_id)
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
