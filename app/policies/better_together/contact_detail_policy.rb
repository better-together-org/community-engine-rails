# frozen_string_literal: true

module BetterTogether
  class ContactDetailPolicy < PlatformRecordPolicy # rubocop:todo Style/Documentation
    def create?
      true # Adjust as per your authorization logic
    end

    def destroy?
      true # Adjust as per your authorization logic
    end

    # Contact components carry their own privacy; anonymous viewers see only public ones.
    class Scope < PlatformRecordPolicy::Scope
      # Components that carry their own privacy (email, phone, website, social
      # account) show anonymous callers only rows that are effectively public.
      def resolve
        base = platform_scoped
        return base if agent || robot.present? || !scope.column_names.include?('privacy')

        effective_public(base)
      end

      protected

      # A public row counts as public only while its platform and community are.
      def effective_public(relation)
        table = relation.klass.arel_table
        relation.where(table[:privacy].eq('public').and(ceiling_open_arel(table)))
      end
    end
  end
end
