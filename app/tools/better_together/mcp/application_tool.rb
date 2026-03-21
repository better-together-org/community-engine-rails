# frozen_string_literal: true

module BetterTogether
  module Mcp
    # Base class for all MCP tools in the Better Together engine
    # Provides Pundit authorization integration and timezone handling for privacy-aware AI interactions
    #
    # User identity is resolved securely via Warden/Devise session.
    # MCP clients without a browser session operate as anonymous users.
    #
    # @example Creating a privacy-aware tool
    #   class ListCommunitiesTool < BetterTogether::Mcp::ApplicationTool
    #     description "List communities accessible to the current user"
    #
    #     arguments do
    #       optional(:privacy_filter).filled(:string).description("Filter by privacy level")
    #     end
    #
    #     def call(privacy_filter: nil)
    #       with_timezone_scope do
    #         communities = policy_scope(BetterTogether::Community)
    #         communities = communities.where(privacy: privacy_filter) if privacy_filter
    #         JSON.generate(communities.map { |c| { id: c.id, name: c.name } })
    #       end
    #     end
    #   end
    class ApplicationTool < FastMcp::Tool
      include BetterTogether::Mcp::PunditIntegration

      protected

      # Escape LIKE metacharacters (%, _) in user-supplied search queries
      # to prevent unintended pattern matching.
      # @param query [String] Raw user input
      # @return [String] Escaped query safe for use in LIKE clauses
      def sanitize_like(query)
        ActiveRecord::Base.sanitize_sql_like(query.to_s)
      end

      # AREL-based search condition for models using Mobility (string translations)
      # and ActionText (rich text content). Avoids raw SQL strings.
      # model_klass: the AR class (e.g. BetterTogether::Page)
      # Returns an AREL node suitable for use in .where()
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def translatable_content_search_condition(model_klass, query)
        sanitized = "%#{sanitize_like(query)}%"
        model_class_str = model_klass.to_s
        model_table = model_klass.arel_table

        str_trans = Arel::Table.new(:mobility_string_translations)
        rich_texts = Arel::Table.new(:action_text_rich_texts)

        title_ids = str_trans
                    .project(str_trans[:translatable_id])
                    .where(
                      str_trans[:translatable_type].eq(model_class_str)
                        .and(str_trans[:key].eq('title'))
                        .and(str_trans[:value].matches(sanitized))
                    )

        content_ids = rich_texts
                      .project(
                        Arel::Nodes::NamedFunction.new(
                          'CAST',
                          [Arel::Nodes::As.new(rich_texts[:record_id], Arel.sql('uuid'))]
                        )
                      )
                      .where(
                        rich_texts[:record_type].eq(model_class_str)
                          .and(rich_texts[:name].eq('content'))
                          .and(rich_texts[:body].matches(sanitized))
                      )

        union = Arel::Nodes::Union.new(title_ids, content_ids)

        model_table[:id].in(
          Arel::SelectManager.new.tap do |m|
            m.project(Arel.star)
            m.from(union.as('matches'))
          end
        )
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Log MCP tool invocations for audit and debugging.
      # Produces structured JSON entries tagged [MCP][tool] in Rails logs.
      # @param tool_name [String] Name of the invoked tool
      # @param args [Hash] Arguments passed to the tool (sensitive keys stripped)
      # @param result_bytes [Integer] Size of the result payload
      def log_invocation(tool_name, args, result_bytes)
        Rails.logger.tagged('MCP', 'tool') do
          Rails.logger.info(
            {
              tool: tool_name,
              user_id: current_user&.id,
              person_id: agent&.id,
              args: args,
              result_bytes: result_bytes,
              timestamp: Time.current.iso8601
            }.to_json
          )
        end
      end
    end
  end

  module ActionTool
    Base = BetterTogether::Mcp::ApplicationTool
  end
end
