# frozen_string_literal: true

# app/policies/better_together/role_policy.rb

module BetterTogether
  class PagePolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      permitted_to?('manage_platform') || (agent.present? && agent.authored_pages.any?)
    end

    def show?
      # Anyone can view published public pages; editors (managers or authors) can view private/unpublished pages
      (record.published? && record.privacy_public?) || update?
    end

    def create?
      permitted_to?('manage_platform')
    end

    def new?
      create?
    end

    def update?
      permitted_to?('manage_platform') || (agent.present? && record.authors.include?(agent))
    end

    def edit?
      update?
    end

    def destroy?
      permitted_to?('manage_platform') && !record.protected?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # Preload title translations and block images for page cards
        base = scope.with_translations
                    .includes(
                      blocks: { background_image_file_attachment: :blob }
                    )

        if permitted_to?('manage_platform')
          # Managers see all pages
          base.order(:identifier)
        elsif agent.present?
          # Authors see their own pages (private or unpublished) plus published public pages
          pt = BetterTogether::Page.arel_table
          at = BetterTogether::Authorship.arel_table

          # Subquery for pages authored by this agent
          authored_subquery = at
                              .project(at[:authorable_id])
                              .where(
                                at[:author_id].eq(agent.id)
                                  .and(at[:authorable_type].eq('BetterTogether::Page'))
                              )

          # Predicate for published public pages
          published_pub = pt[:published_at].lteq(Time.current)
                                           .and(pt[:privacy].eq('public'))

          # Combine predicates: either published public or authored
          base.where(published_pub.or(pt[:id].in(authored_subquery)))
        else
          # Regular users only see published public pages
          base.published
              .privacy_public
        end
      end
    end
  end
end
