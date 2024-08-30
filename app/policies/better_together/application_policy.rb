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
      attr_reader :user, :scope

      def initialize(user, scope)
        @user = user
        @agent = user&.person
        @scope = scope
      end

      def resolve
        scope.all
      end
    end

    protected

    def permitted_to?(permission_identifier) # rubocop:todo Naming/PredicateName
      agent.permitted_to?(permission_identifier)
    end
  end
end
