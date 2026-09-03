# frozen_string_literal: true

module BetterTogether
  module Content
    # Authorization for content blocks.
    #
    # `index?/create?/update?/destroy?` (and the admin `*_search?` helpers) are
    # platform-content-manager only -- editing a block is a management action.
    #
    # `show?` / `download?` answer "may this viewer SEE this block (and its
    # attached media) where it is rendered". A block is bounded by its page:
    # it is never visible on a page the viewer cannot already see. Within that
    # bound:
    #   - public    block -> anyone who can see the page
    #   - community block -> members of the block's platform community, + editors
    #   - private   block -> platform content managers / page contributors only
    class BlockPolicy < PlatformRecordPolicy # rubocop:todo Style/Documentation
      def index?
        platform_content_manager?
      end

      def show?
        # Type-level checks (record is the class, not an instance) reduce to the
        # legacy "may this viewer manage blocks of this type" question.
        return platform_content_manager? unless record.is_a?(BetterTogether::Content::Block)
        return true if editor_access?
        return false unless block_on_a_visible_page?

        public_or_member_scoped_community?(record)
      end

      # ActiveStorageSecurity#enforce_download_policy! calls this for a block's
      # attached blobs (background/hero images). Same decision as #show?.
      alias download? show?

      def create?
        platform_content_manager?
      end

      def new?
        create?
      end

      def update?
        platform_content_manager?
      end

      def edit?
        update?
      end

      def destroy?
        platform_content_manager?
      end

      def preview_markdown?
        user.present?
      end

      def resource_search?
        platform_content_manager?
      end

      class Scope < Scope # rubocop:todo Style/Documentation
        def resolve
          ordered = platform_scoped.includes(:pages)
                                   .order(BetterTogether::Content::Block.arel_table[:created_at].desc)
          return ordered if platform_content_manager?

          # visible_privacy_query: public [+ community for members of the block's
          # platform community, via the Content::Block case added to
          # ApplicationPolicy::Scope#scoped_community_privacy_query] [+ robot scopes].
          table = BetterTogether::Content::Block.arel_table
          query = visible_privacy_query(table)
          query = query.or(table[:creator_id].eq(agent.id)) if agent
          ordered.where(query)
        end

        private

        def platform_content_manager?
          permitted_to?('manage_platform_settings', current_platform) ||
            permitted_to?('manage_platform', current_platform)
        end
      end

      private

      def editor_access?
        return true if platform_content_manager?
        return false unless agent.present?

        record.creator_id == agent.id || contributor_of_a_page?
      end

      def contributor_of_a_page?
        record.pages.any? { |page| page.editable_contributors.include?(agent) }
      end

      # A block with no page assignment is platform chrome (e.g. a Content::PlatformBlock
      # target) -- not page-bound, treat as visible. Otherwise it needs at least one
      # page the viewer can see per PagePolicy.
      def block_on_a_visible_page?
        return true if record.pages.blank?

        BetterTogether::PagePolicy::Scope.new(robot || user, record.pages).resolve.exists?
      end

      def platform_content_manager?(target = record)
        platform = (target.respond_to?(:platform) ? target.platform : nil) || current_platform
        user.present? && (permitted_to?('manage_platform_settings', platform) || permitted_to?('manage_platform', platform))
      end
    end
  end
end
