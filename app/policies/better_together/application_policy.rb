# frozen_string_literal: true

module BetterTogether
  class ApplicationPolicy # rubocop:todo Style/Documentation
    attr_reader :user, :record, :agent

    def initialize(user, record)
      @user = user
      @agent = user&.person
      @record = record
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
      attr_reader :user, :scope, :agent

      def initialize(user, scope)
        @user = user
        @agent = user&.person
        @scope = scope
      end

      def resolve # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        result = scope.order(created_at: :desc)

        table = scope.arel_table

        if scope.ancestors.include?(BetterTogether::Privacy)
          # Only list records that are public unless otherwise granted permission
          query = table[:privacy].eq('public')

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
        agent&.permitted_to?(permission_identifier, record)
      end
    end

    protected

    def permitted_to?(permission_identifier, record = nil)
      agent&.permitted_to?(permission_identifier, record)
    end
  end
end
