# frozen_string_literal: true

module BetterTogether
  # Access control for comments
  class CommentPolicy < PlatformRecordPolicy
    include SelfServicePublishablePolicy

    def show?
      commentable = record.commentable
      return false unless commentable

      commentable_visible_to_agent?(commentable) && commentable_visibility_permits?(commentable)
    end

    def create?
      return false unless user.present?
      return false if blocked_by_commentable_creator?
      return false unless platform_manager? || accepted_content_publishing_agreement?
      return false unless show?

      # No manager bypass here, deliberately: platform/community managers are subject to
      # the same posting rule as everyone else. Their destroy? moderation rights over
      # other people's comments are unaffected.
      commentable_accepts_new_comments?(record.commentable)
    end
    alias new? create?

    def destroy?
      creator_of?(record) || community_content_manager? || platform_manager?
    end

    # Scope for resolving visible comments
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        # Richer than plain include_creator: the comment list renders each creator via
        # the people/mention partial, which needs the creator's translated slug (for
        # person_path) and profile image — same shape as ConversationPolicy::Scope's
        # participant eager-loading, to avoid an N+1 per comment on both fronts.
        base = platform_scoped.oldest_first.includes(creator: [:string_translations, { profile_image_attachment: :blob }])
        base = base.excluding_blocked_for(agent) if agent
        restrict_to_visible_and_permitted(base)
      end

      private

      # Comments are polymorphic, so this can't be one generic SQL join across arbitrary
      # commentable-type policy scopes. In practice a query is already scoped to a single
      # commentable (e.g. policy_scope(post.comments)), so resolving the small set of
      # distinct (type, id) pairs actually present in the relation — not the whole class
      # table — keeps this correct without loading every comment row into memory.
      # Delegates to CommentPolicy#show? (via a transient, unsaved Comment) so the
      # visibility rule has exactly one implementation.
      def restrict_to_visible_and_permitted(relation)
        pairs = relation.unscope(:order).distinct.pluck(:commentable_type, :commentable_id)
        allowed_pairs = pairs.select { |type, id| commentable_pair_permitted?(type, id) }
        return relation.none if allowed_pairs.empty?

        relation.where(allowed_pairs_condition(relation, allowed_pairs))
      end

      def allowed_pairs_condition(relation, allowed_pairs)
        table = relation.arel_table
        allowed_pairs
          .map { |type, id| table[:commentable_type].eq(type).and(table[:commentable_id].eq(id)) }
          .reduce(:or)
      end

      def commentable_pair_permitted?(type, id)
        klass = type.safe_constantize
        return false unless klass

        commentable = klass.find_by(id: id)
        return false unless commentable

        CommentPolicy.new(user, BetterTogether::Comment.new(commentable:)).show?
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

    def commentable_visible_to_agent?(commentable)
      Pundit.policy_scope(user, commentable.class)&.where(id: commentable.id)&.exists? || false
    end

    def commentable_visibility_permits?(commentable)
      return true unless commentable.respond_to?(:comment_visibility)
      return true unless commentable.comment_visibility == 'community'

      member_of_resolved_community?(commentable)
    end

    def commentable_accepts_new_comments?(commentable)
      return true unless commentable.respond_to?(:comment_permission)

      case commentable.comment_permission
      when 'disabled' then false
      when 'community' then member_of_resolved_community?(commentable)
      else true
      end
    end
  end
end
