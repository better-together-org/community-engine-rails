# frozen_string_literal: true

module RuboCop
  module Cop
    module BetterTogether
      # Flags raw SQL string literals passed as the first argument to ActiveRecord
      # query methods. Use Arel, hash syntax, or symbol syntax instead so Rails
      # generates fully-qualified, join-safe SQL automatically.
      #
      # When a raw SQL fragment is genuinely unavoidable (e.g. a database function
      # with no Arel equivalent), wrap it with +Arel.sql()+ and add a
      # +rubocop:disable+ inline comment with a documented rationale so the
      # exception is visible in code review.
      #
      # @example Bad
      #   scope.order('created_at DESC')
      #   Model.where('status = ?', status)
      #   scope.having('COUNT(*) > 1')
      #   scope.group('DATE(created_at)')
      #
      # @example Good — Arel
      #   scope.order(Model.arel_table[:created_at].desc)
      #   scope.order(arel_table[:position].asc)
      #   scope.having(arel_table[:id].count.gt(1))
      #
      # @example Good — hash / symbol (where/order)
      #   Model.where(status: status)
      #   Model.order(created_at: :desc)
      #
      # @example Good — Arel.sql() for unavoidable fragments
      #   # rubocop:disable BetterTogether/NoRawSqlInQueries -- RANDOM() has no Arel equivalent
      #   scope.order(Arel.sql('RANDOM()'))
      #   # rubocop:enable BetterTogether/NoRawSqlInQueries
      class NoRawSqlInQueries < Base
        MSG = 'Avoid raw SQL strings in `%<method>s`; use Arel, hash, or symbol ' \
              'syntax. For unavoidable fragments use Arel.sql() with a ' \
              'rubocop:disable rationale.'

        RESTRICT_ON_SEND = %i[order reorder where having select group joins].freeze

        def on_send(node)
          first_arg = node.first_argument
          return unless first_arg&.str_type?
          return if arel_sql_wrapper?(first_arg)
          return if capybara_select?(node)

          add_offense(node.loc.selector, message: format(MSG, method: node.method_name))
        end

        private

        # Allow explicit Arel.sql('...') — that signals the author made a
        # deliberate, documented choice to use a raw fragment.
        def arel_sql_wrapper?(node)
          node.send_type? &&
            node.method_name == :sql &&
            node.receiver&.const_type? &&
            node.receiver.short_name == :Arel
        end

        # Capybara's `select 'option', from: 'field'` shares the method name
        # with ActiveRecord::QueryMethods#select. Distinguish by the presence
        # of a `from:` keyword argument, which is Capybara-only.
        def capybara_select?(node)
          node.method_name == :select &&
            node.arguments.any? { |arg| arg.hash_type? && capybara_from_key?(arg) }
        end

        def capybara_from_key?(hash_node)
          hash_node.pairs.any? { |pair| pair.key.sym_type? && pair.key.value == :from }
        end
      end
    end
  end
end
