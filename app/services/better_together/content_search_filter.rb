# frozen_string_literal: true

module BetterTogether
  # Base class for content-type search filters (posts, events, pages, etc.)
  # Provides common filtering logic: text search (ILIKE), categories, pagination.
  # Subclasses override filter_by_status, filter_by_privacy, order_by for resource-specific behavior.
  # rubocop:todo Metrics/ClassLength
  class ContentSearchFilter
    def self.call(resource_class:, relation:, params:)
      new(resource_class:, relation:, params:).call
    end

    def initialize(resource_class:, relation:, params:)
      @resource_class = resource_class
      @relation = relation
      @params = params
    end

    def call
      search_text
      filter_by_categories
      filter_by_resource_specific_associations
      filter_by_resource_specific_status
      order_by
      paginate
      @relation
    end

    private

    attr_reader :resource_class, :params

    # Subclasses override these methods for resource-specific behavior.

    # Called after filter_by_categories. Subclasses add association-based filters
    # (e.g. authors, communities) here without duplicating the full call sequence.
    def filter_by_resource_specific_associations
      @relation
    end

    # Called after filter_by_resource_specific_associations.
    # Subclasses implement privacy, status, or other resource-specific filters here.
    def filter_by_resource_specific_status
      @relation
    end

    # Override for resource-specific ordering.
    # Default: created_at desc (newest first)
    def default_order_by
      @relation.reorder(created_at: :desc)
    end

    # ====== Shared implementations (inherited by subclasses) ======

    def search_text # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      q = params[:q].to_s
      return @relation if q.blank?

      pattern = "%#{q.downcase}%"
      current_locale = I18n.locale.to_s
      default_locale = I18n.default_locale.to_s

      main = resource_class.arel_table
      art  = Arel::Table.new(:action_text_rich_texts)
      nst_c = Arel::Table.new(:mobility_string_translations).alias('nst_cur')
      nst_d = Arel::Table.new(:mobility_string_translations).alias('nst_def')

      joins = []
      joins << main.join(art, Arel::Nodes::OuterJoin).on(
        art[:record_type].eq(resource_class.name)
           .and(art[:record_id].eq(main[:id]))
           .and(art[:name].eq(action_text_field))
           .and(art[:locale].eq(current_locale).or(art[:locale].eq(nil)))
      ).join_sources

      joins << main.join(nst_c, Arel::Nodes::OuterJoin).on(
        nst_c[:translatable_type].eq(resource_class.name)
           .and(nst_c[:translatable_id].eq(main[:id]))
           .and(nst_c[:key].eq(mobility_title_key))
           .and(nst_c[:locale].eq(current_locale))
      ).join_sources
      joins << main.join(nst_d, Arel::Nodes::OuterJoin).on(
        nst_d[:translatable_type].eq(resource_class.name)
           .and(nst_d[:translatable_id].eq(main[:id]))
           .and(nst_d[:key].eq(mobility_title_key))
           .and(nst_d[:locale].eq(default_locale))
      ).join_sources

      coalesce = ->(a, b) { Arel::Nodes::NamedFunction.new('COALESCE', [a, b]) }
      lower    = ->(expr) { Arel::Nodes::NamedFunction.new('LOWER', [expr]) }

      title_expr = coalesce.call(nst_c[:value], nst_d[:value])

      condition = lower.call(title_expr).matches(pattern)
                       .or(lower.call(art[:body]).matches(pattern))

      @relation = @relation.joins(joins.flatten).where(condition).distinct
    end

    def filter_by_categories # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      ids = Array(params[:category_ids]).reject(&:blank?)
      return @relation if ids.empty?

      btc = Arel::Table.new(:better_together_categorizations)
      cat = Arel::Table.new(:better_together_categories)
      main = resource_class.arel_table

      joins = []
      joins << main.join(btc, Arel::Nodes::OuterJoin).on(
        btc[:categorizable_type].eq(resource_class.name)
           .and(btc[:categorizable_id].eq(main[:id]))
      ).join_sources
      joins << btc.join(cat, Arel::Nodes::OuterJoin).on(
        cat[:id].eq(btc[:category_id])
      ).join_sources

      @relation = @relation.joins(joins.flatten)
                           .where(BetterTogether::Category.table_name => { id: ids })
                           .distinct
    end

    def order_by
      @relation = case params[:order_by]
                  when 'oldest' then @relation.reorder(created_at: :asc)
                  else default_order_by
                  end
    end

    def paginate
      per_page = params[:per_page].presence
      allowed = %w[10 20 50]
      per_page = allowed.include?(per_page.to_s) ? per_page.to_i : 20

      out = @relation
      out = out.page(params[:page]) if out.respond_to?(:page)
      out = out.per(per_page) if out.respond_to?(:per)
      @relation = out
    end

    # Subclasses override these for resource-specific field names.
    # For Posts: 'content'; for Events: 'description'
    def action_text_field
      raise NotImplementedError, "#{self.class} must implement action_text_field"
    end

    # For Posts: 'title'; for Events: 'title' (same in both, but future extensibility)
    def mobility_title_key
      'title'
    end
  end
  # rubocop:enable Metrics/ClassLength
end
