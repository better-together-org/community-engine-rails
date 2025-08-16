# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Builds common filters and search joins for Offer/Request index pages
    class SearchFilter
      def self.call(resource_class:, relation:, params:)
        new(resource_class:, relation:, params:).call
      end

      def initialize(resource_class:, relation:, params:)
        @resource_class = resource_class
        @relation = relation
        @params = params
      end

      def call
        filter_by_categories
        search_text
        filter_by_status
        order_by
        paginate
      end

      private

      attr_reader :resource_class, :relation, :params

      def filter_by_categories
        ids = Array(params[:types_filter]).reject(&:blank?)
        return relation if ids.empty?

        @relation = relation.joins(:categories)
                             .where(BetterTogether::Joatu::Category.table_name => { id: ids })
      end

      def search_text # rubocop:todo Metrics/AbcSize
        q = params[:q].to_s
        return relation if q.blank?

        pattern = "%#{q.downcase}%"
        current_locale = I18n.locale.to_s
        default_locale = I18n.default_locale.to_s

        main  = resource_class.arel_table
        art   = Arel::Table.new(:action_text_rich_texts)
        nst_c = Arel::Table.new(:mobility_string_translations).alias('nst_cur')
        nst_d = Arel::Table.new(:mobility_string_translations).alias('nst_def')
        btc   = Arel::Table.new(:better_together_categorizations)
        cat   = Arel::Table.new(:better_together_categories)
        cst_c = Arel::Table.new(:mobility_string_translations).alias('cst_cur')
        cst_d = Arel::Table.new(:mobility_string_translations).alias('cst_def')

        joins = []
        joins << main.join(art, Arel::Nodes::OuterJoin).on(
          art[:record_type].eq(resource_class.name)
             .and(art[:record_id].eq(main[:id]))
             .and(art[:name].eq('description'))
             .and(art[:locale].eq(current_locale).or(art[:locale].eq(nil)))
        ).join_sources

        joins << main.join(nst_c, Arel::Nodes::OuterJoin).on(
          nst_c[:translatable_type].eq(resource_class.name)
             .and(nst_c[:translatable_id].eq(main[:id]))
             .and(nst_c[:key].eq('name'))
             .and(nst_c[:locale].eq(current_locale))
        ).join_sources
        joins << main.join(nst_d, Arel::Nodes::OuterJoin).on(
          nst_d[:translatable_type].eq(resource_class.name)
             .and(nst_d[:translatable_id].eq(main[:id]))
             .and(nst_d[:key].eq('name'))
             .and(nst_d[:locale].eq(default_locale))
        ).join_sources

        joins << main.join(btc, Arel::Nodes::OuterJoin).on(
          btc[:categorizable_type].eq(resource_class.name)
             .and(btc[:categorizable_id].eq(main[:id]))
        ).join_sources
        joins << main.join(cat, Arel::Nodes::OuterJoin).on(
          cat[:id].eq(btc[:category_id])
        ).join_sources
        joins << main.join(cst_c, Arel::Nodes::OuterJoin).on(
          cst_c[:translatable_id].eq(cat[:id])
             .and(cst_c[:key].eq('name'))
             .and(cst_c[:locale].eq(current_locale))
        ).join_sources
        joins << main.join(cst_d, Arel::Nodes::OuterJoin).on(
          cst_d[:translatable_id].eq(cat[:id])
             .and(cst_d[:key].eq('name'))
             .and(cst_d[:locale].eq(default_locale))
        ).join_sources

        coalesce = ->(a, b) { Arel::Nodes::NamedFunction.new('COALESCE', [a, b]) }
        lower    = ->(expr) { Arel::Nodes::NamedFunction.new('LOWER', [expr]) }

        name_expr     = coalesce.call(nst_c[:value], nst_d[:value])
        cat_name_expr = coalesce.call(cst_c[:value], cst_d[:value])

        condition = lower.call(name_expr).matches(pattern)
                      .or(lower.call(art[:body]).matches(pattern))
                      .or(lower.call(cat_name_expr).matches(pattern))

        @relation = relation.joins(joins.flatten).where(condition).distinct
      end

      def filter_by_status
        status = params[:status].to_s
        return relation if status.blank?
        return relation unless %w[open closed].include?(status)

        @relation = relation.where(status:)
      end

      def order_by
        @relation = case params[:order_by]
                    when 'oldest' then relation.order(created_at: :asc)
                    else relation.order(created_at: :desc)
                    end
      end

      def paginate
        per_page = params[:per_page].presence
        allowed = %w[10 20 50]
        per_page = allowed.include?(per_page.to_s) ? per_page.to_i : 20

        out = relation
        out = out.page(params[:page]) if out.respond_to?(:page)
        out = out.per(per_page) if out.respond_to?(:per)
        out
      end
    end
  end
end

