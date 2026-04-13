# frozen_string_literal: true

# app/policies/better_together/role_policy.rb

module BetterTogether
  class PagePolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      platform_content_manager? || (agent.present? && (agent.authored_pages.any? || agent.contributed_pages.any?))
    end

    def show?
      # Community visibility is limited to members of the page's scoped community.
      # Editors can still view private/unpublished pages.
      (record.published? && public_or_member_scoped_community?(record)) || update?
    end

    def create?
      platform_content_manager?
    end

    def new?
      create?
    end

    def create_release_package_draft?
      create?
    end

    def update?
      platform_content_manager? || (agent.present? && record.editable_contributors.include?(agent))
    end

    def edit?
      update?
    end

    def destroy?
      platform_content_manager? && !record.protected?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # Preload title translations and block images for page cards
        base = scope.with_translations
                    .includes(
                      blocks: { background_image_file_attachment: :blob }
                    )
        pt = BetterTogether::Page.arel_table

        if platform_content_manager?
          # Platform stewards and host-community content managers see all pages
          base.order(:identifier)
        elsif robot.present?
          page_query = visible_privacy_query(pt).and(pt[:published_at].lteq(Time.current))
          base.where(page_query)
        elsif agent.present?
          # Contributors see their own pages (private or unpublished) plus published public pages
          at = BetterTogether::Authorship.arel_table

          # Subquery for pages with author/editor contributions by this agent
          authored_subquery = at
                              .project(at[:authorable_id])
                              .where(
                                at[:author_type].eq(agent.class.name)
                                  .and(at[:author_id].eq(agent.id))
                                  .and(at[:role].in([
                                                      BetterTogether::Authorship::AUTHOR_ROLE,
                                                      BetterTogether::Authorship::EDITOR_ROLE
                                                    ]))
                                  .and(at[:authorable_type].eq('BetterTogether::Page'))
                              )

          visible_privacy = visible_privacy_query(pt)

          # Predicate for published pages visible to this audience
          published_pub = pt[:published_at].lteq(Time.current)
                                           .and(visible_privacy)

          # Combine predicates: either published public or authored
          base.where(published_pub.or(pt[:id].in(authored_subquery)))
        else
          # Guests only see published public pages
          base.published.privacy_public
        end
      end

      private

      # Scope-level check uses host_community because there is no specific record in scope context.
      # Compare with PagePolicy#platform_content_manager? (below) which checks record.community.
      def platform_content_manager?
        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform') ||
          permitted_to?('manage_community_content', host_community)
      end

      def host_community
        @host_community ||= BetterTogether::Community.find_by(host: true)
      end
    end

    private

    # Record-level check: uses the page's own community so that community-content-managers
    # of that specific community can edit/destroy the page. This intentionally differs from
    # Scope#platform_content_manager? which falls back to the host community for list queries.
    def platform_content_manager?
      permitted_to?('manage_platform_settings') ||
        permitted_to?('manage_platform') ||
        permitted_to?('manage_community_content', record.community)
    end
  end
end
