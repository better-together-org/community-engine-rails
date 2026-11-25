# frozen_string_literal: true

module BetterTogether
  # Lets a policy honor an active break-glass grant for the one page that opts in, read only.
  # show?, download?, the scope and the API stay closed to grants. The controller that calls
  # break_glass_show? writes the audit row when break_glass_only? is true.
  # Assumes inclusion into an ApplicationPolicy subclass (uses #agent, #record and #show?).
  module BreakGlassReadablePolicy
    extend ActiveSupport::Concern

    def break_glass_show?
      show? || break_glass_grant.present?
    end

    # The grant that lets this person read this record right now, if any.
    def break_glass_grant
      return @break_glass_grant if defined?(@break_glass_grant)

      @break_glass_grant = agent.present? && record.persisted? ? current_break_glass_grant : nil
    end

    # True when a grant, and nothing else, is what lets this person read the record.
    def break_glass_only?
      break_glass_grant.present? && !show?
    end

    private

    def current_break_glass_grant
      BetterTogether::BreakGlassGrant.current.find_by(grantee: agent, subject: record)
    end
  end
end
