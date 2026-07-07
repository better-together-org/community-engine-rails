# frozen_string_literal: true

module BetterTogether
  # Access control for comments
  class CommentPolicy < PlatformRecordPolicy
    include SelfServicePublishablePolicy

    def show?
      Pundit.policy(user, record.commentable)&.show? || false
    end

    def create?
      return false unless user.present?
      return false if blocked_by_commentable_creator?
      return false unless platform_manager? || accepted_content_publishing_agreement?

      Pundit.policy(user, record.commentable)&.show? || false
    end
    alias new? create?

    def destroy?
      creator_of?(record) || community_content_manager? || platform_manager?
    end

    # Scope for resolving visible comments
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        base = platform_scoped.oldest_first.include_creator
        agent ? base.excluding_blocked_for(agent) : base
      end
    end

    private

    def community_content_manager?
      target_community = resolved_community_for(record.commentable)
      return false unless target_community

      permitted_to?('manage_community_content', target_community)
    end

    def blocked_by_commentable_creator?
      return false unless agent
      return false unless record.commentable.respond_to?(:creator_id) && record.commentable.creator_id

      agent.blockers.exists?(id: record.commentable.creator_id)
    end
  end
end
