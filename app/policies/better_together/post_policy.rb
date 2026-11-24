# frozen_string_literal: true

module BetterTogether
  # Access control for posts
  class PostPolicy < PlatformRecordPolicy
    include SelfServicePublishablePolicy
    include PlatformEditorialContent

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
      return false unless user.present?

      platform_manager? || community_content_manager? || self_service_content_creator?
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
    class Scope < PlatformRecordPolicy::Scope
      include PlatformEditorialContent

      # Managers see the platform's editorial posts (drafts and private included), published
      # non-private posts and whatever any other person could see. Private and draft posts in other
      # communities stay with their creators and community content managers.
      def resolve
        standard = standard_posts
        return standard unless platform_content_manager?

        platform_scoped.latest_first.where(manager_visibility(standard))
      end

      private

      def manager_visibility(standard)
        posts_table[:id].in(ids_of(standard)).or(posts_table[:id].in(ids_of(non_private_posts))).or(editorial_posts)
      end

      def non_private_posts
        platform_scoped.published.where.not(privacy: 'private')
      end

      def ids_of(relation)
        relation.reorder(nil).select(:id).arel
      end

      def standard_posts
        base = platform_scoped.published.latest_first
        base = base.excluding_blocked_for(agent) if agent
        base.where(standard_visibility)
      end

      def standard_visibility
        visible_posts = visible_privacy_query(posts_table)
        return visible_posts unless agent

        visible_posts.or(posts_table[:creator_id].eq(agent.id))
      end

      def editorial_posts
        posts_table[:community_id].eq(nil).or(posts_table[:community_id].in(platform_editorial_community_ids))
      end

      def posts_table
        ::BetterTogether::Post.arel_table
      end

      def platform_content_manager?
        permitted_to?('manage_platform_settings', current_platform) || permitted_to?('manage_platform', current_platform)
      end
    end

    private

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
      creator_of?(record) || platform_editorial_manager?
    end

    # A platform manager's authority covers the platform's own posts and published
    # non-private posts, not private or draft posts that live in a community.
    def platform_editorial_manager?
      platform_manager? && (platform_editorial_community?(record.try(:community_id), record.try(:platform)) ||
                            (record.try(:published?) && record.privacy != 'private'))
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
