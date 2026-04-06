# frozen_string_literal: true

module BetterTogether
  class ApplicationPolicy # rubocop:todo Style/Documentation
    attr_reader :user, :record, :agent, :invitation_token

    def initialize(user, record, invitation_token: nil)
      @user = user
      @agent = user&.person
      @record = record
      @invitation_token = invitation_token
    end

    def index?
      false
    end

    def show?
      false
    end

    def create?
      false
    end

    def new?
      create?
    end

    def update?
      false
    end

    def edit?
      update?
    end

    def destroy?
      false
    end

    class Scope # rubocop:todo Style/Documentation
      attr_reader :user, :scope, :agent, :invitation_token, :options

      def initialize(user, scope, invitation_token: nil, **options)
        @user = user
        @agent = user&.person
        @scope = scope
        @invitation_token = invitation_token
        @options = options
      end

      def resolve # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        result = scope.order(created_at: :desc)

        table = scope.arel_table

        if scope.ancestors.include?(BetterTogether::Privacy)
          # Signed-in people can see community-scoped records. Private records still
          # require an explicit management, membership, or ownership path.
          query = visible_privacy_query(table)

          if permitted_to?('manage_platform')
            query = query.or(table[:privacy].eq('private'))
          elsif agent
            if scope.ancestors.include?(BetterTogether::Joinable) && scope.membership_class.present?
              membership_table = scope.membership_class.arel_table
              query = query.or(
                table[:id].in(
                  membership_table
                    .where(membership_table[:member_id]
                    .eq(agent.id))
                    .project(:joinable_id)
                )
              )
            end

            if scope.ancestors.include?(BetterTogether::Creatable)
              query = query.or(
                table[:creator_id].eq(agent.id)
              )
            end
          end

          result = result.where(query)
        end

        result
      end

      def permitted_to?(permission_identifier, record = nil)
        !!agent&.permitted_to?(permission_identifier, record)
      end

      private

      def visible_privacy_query(table)
        query = table[:privacy].eq('public')
        return query unless agent

        community_query = scoped_community_privacy_query(table)
        community_query ? query.or(community_query) : query
      end

      def scoped_community_privacy_query(table) # rubocop:todo Metrics/AbcSize
        return nil if scoped_community_ids.empty?

        case scope.name
        when 'BetterTogether::Community'
          table[:privacy].eq('community').and(table[:id].in(scoped_community_ids))
        when 'BetterTogether::Page', 'BetterTogether::Calendar', 'BetterTogether::Platform'
          table[:privacy].eq('community').and(table[:community_id].in(scoped_community_ids))
        when 'BetterTogether::Post', 'BetterTogether::Event'
          table[:privacy].eq('community').and(table[:platform_id].in(scoped_platform_ids))
        when 'BetterTogether::CallForInterest'
          scoped_call_for_interest_privacy_query(table)
        end
      end

      def scoped_call_for_interest_privacy_query(table) # rubocop:todo Metrics/AbcSize
        scoped_query = call_for_interest_scope_clauses(table).reduce { |query, clause| query.or(clause) }
        return nil unless scoped_query

        table[:privacy].eq('community').and(scoped_query)
      end

      def call_for_interest_scope_clauses(table)
        {
          'BetterTogether::Community' => scoped_community_ids,
          'BetterTogether::Calendar' => scoped_calendar_ids,
          'BetterTogether::Platform' => scoped_platform_ids,
          'BetterTogether::Event' => scoped_event_ids,
          'BetterTogether::Page' => scoped_page_ids
        }.map do |interestable_type, relation|
          table[:interestable_type].eq(interestable_type).and(table[:interestable_id].in(relation))
        end
      end

      def scoped_community_ids
        return [] unless agent.present?

        @scoped_community_ids ||= agent.person_community_memberships.pluck(:joinable_id)
      end

      def scoped_platform_ids
        return [] unless agent.present?

        @scoped_platform_ids ||= BetterTogether::Platform.where(community_id: scoped_community_ids).pluck(:id)
      end

      def scoped_event_ids
        return [] unless agent.present?

        @scoped_event_ids ||= BetterTogether::Event.where(platform_id: scoped_platform_ids).pluck(:id)
      end

      def scoped_page_ids
        return [] unless agent.present?

        @scoped_page_ids ||= BetterTogether::Page.where(community_id: scoped_community_ids)
                                                 .or(BetterTogether::Page.where(platform_id: scoped_platform_ids))
                                                 .pluck(:id)
      end

      def scoped_calendar_ids
        return [] unless agent.present?

        @scoped_calendar_ids ||= BetterTogether::Calendar.where(community_id: scoped_community_ids).pluck(:id)
      end
    end

    protected

    def permitted_to?(permission_identifier, record = nil)
      !!agent&.permitted_to?(permission_identifier, record)
    end

    def can_read_people_directory?(target = nil)
      permitted_to?('list_person', target)
    end

    def can_read_private_people?(target = nil)
      permitted_to?('read_person', target)
    end

    def can_manage_user_accounts?(target = nil)
      permitted_to?('manage_platform_users', target)
    end

    def can_view_metrics_dashboard?(target = nil)
      permitted_to?('view_metrics_dashboard', target)
    end

    def can_create_metrics_reports?(target = nil)
      permitted_to?('create_metrics_reports', target)
    end

    def can_download_metrics_reports?(target = nil)
      permitted_to?('download_metrics_reports', target)
    end

    def can_review_safety_disclosures?(target = nil)
      permitted_to?('manage_platform_safety', target)
    end

    def can_manage_webhook_endpoints?(target = nil)
      permitted_to?('manage_platform_api', target)
    end

    def public_or_member_scoped_community?(target = record)
      privacy_public?(target) || (privacy_community?(target) && member_of_resolved_community?(target))
    end

    def privacy_public?(target = record)
      target.respond_to?(:privacy_public?) && target.privacy_public?
    end

    def privacy_community?(target = record)
      target.respond_to?(:privacy_community?) && target.privacy_community?
    end

    def member_of_resolved_community?(target = record)
      return false unless agent.present?

      community = resolved_community_for(target)
      return false unless community.present?

      agent.person_community_memberships.exists?(joinable: community)
    end

    def resolved_community_for(target)
      return if target.nil?

      direct_resolved_community_for(target) ||
        delegated_resolved_community_for(target, :platform) ||
        delegated_resolved_community_for(target, :interestable)
    end

    def direct_resolved_community_for(target)
      return target if target.is_a?(BetterTogether::Community)
      return target.community if target.respond_to?(:community) && target.community.present?

      target.primary_community if target.respond_to?(:primary_community) && target.primary_community.present?
    end

    def delegated_resolved_community_for(target, association)
      return unless target.respond_to?(association)

      associated_record = target.public_send(association)
      return if associated_record.blank?

      resolved_community_for(associated_record)
    end
  end
end
