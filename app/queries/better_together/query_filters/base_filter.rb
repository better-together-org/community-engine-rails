
module BetterTogether
  module QueryFilters
    # Base class for query filters
    class BaseFilter
      def initialize(filters, tables)
        self.filters = filters
        self.tables = tables
      end

      def apply
        set_filters
        query_conditions
      end

      protected

      attr_accessor :query_conditions, :filters, :tables

      def set_filters
        raise ::NoMethodError, 'you must override this method in the subclass to active the filters defined for this class'
      end

      def append_condition(condition, use_and: true)
        return self.query_conditions = condition if query_conditions.nil?

        if use_and
          self.query_conditions = query_conditions.and(condition)
        else
          self.query_conditions = query_conditions.or(condition)
        end
      end
    end
  end
end
