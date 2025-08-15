# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Request
    class RequestsController < FriendlyResourceController
      def index
        @requests = resource_class.all

        # Category filter (treat types_filter[] as category IDs)
        if params[:types_filter].present?
          ids = Array(params[:types_filter]).reject(&:blank?)
          if ids.any?
            @requests = @requests.joins(:categories)
                                 .where(BetterTogether::Joatu::Category.table_name => { id: ids })
          end
        end

        # Text search on Mobility name, ActionText description body, and category name
        if params[:q].present?
          term = "%#{params[:q].to_s}%"
          current_locale = I18n.locale.to_s
          default_locale = I18n.default_locale.to_s
          rt_join = <<~SQL.squish
            LEFT JOIN action_text_rich_texts art
              ON art.record_type = '#{resource_class.name}'
             AND art.record_id = #{resource_class.table_name}.id
             AND art.name = 'description'
             AND (art.locale IS NULL OR art.locale = '#{current_locale}')
          SQL
          name_join = <<~SQL.squish
            LEFT JOIN mobility_string_translations nst_cur
              ON nst_cur.translatable_type = '#{resource_class.name}'
             AND nst_cur.translatable_id = #{resource_class.table_name}.id
             AND nst_cur.key = 'name'
             AND nst_cur.locale = '#{current_locale}'
            LEFT JOIN mobility_string_translations nst_def
              ON nst_def.translatable_type = '#{resource_class.name}'
             AND nst_def.translatable_id = #{resource_class.table_name}.id
             AND nst_def.key = 'name'
             AND nst_def.locale = '#{default_locale}'
          SQL
          cat_join = <<~SQL.squish
            LEFT JOIN better_together_categorizations btc
              ON btc.categorizable_type = '#{resource_class.name}'
             AND btc.categorizable_id = #{resource_class.table_name}.id
            LEFT JOIN better_together_categories cat
              ON cat.id = btc.category_id
            LEFT JOIN mobility_string_translations cst_cur
              ON cst_cur.translatable_id = cat.id
             AND cst_cur.key = 'name'
             AND cst_cur.locale = '#{current_locale}'
            LEFT JOIN mobility_string_translations cst_def
              ON cst_def.translatable_id = cat.id
             AND cst_def.key = 'name'
             AND cst_def.locale = '#{default_locale}'
          SQL
          @requests = @requests.joins(rt_join).joins(name_join).joins(cat_join)
                               .where(
                                 "COALESCE(nst_cur.value, nst_def.value) ILIKE :term OR art.body ILIKE :term OR COALESCE(cst_cur.value, cst_def.value) ILIKE :term",
                                 term:
                               ).distinct
        end

        # Status filter
        if params[:status].present? && %w[open closed].include?(params[:status].to_s)
          @requests = @requests.where(status: params[:status])
        end

        @requests = case params[:order_by]
                    when 'oldest' then @requests.order(created_at: :asc)
                    else @requests.order(created_at: :desc)
                    end

        allowed_per_page = %w[10 20 50]
        per_page = params[:per_page].presence
        per_page = allowed_per_page.include?(per_page.to_s) ? per_page.to_i : 20
        @requests = @requests.page(params[:page]) if @requests.respond_to?(:page)
        @requests = @requests.per(per_page) if @requests.respond_to?(:per)

        # Build options for the filter form
        categories = BetterTogether::Joatu::Category.all.to_a
        categories.sort_by! { |c| c.name.to_s.downcase }
        @category_options = categories.map { |c| [c.name, c.id] }
      end
      # GET /joatu/requests/:id/matches
      def matches
        @request = BetterTogether::Joatu::Request.find(params[:id])
        @matches = BetterTogether::Joatu::Matchmaker.match(@request)
      end

      protected

      def resource_class
        ::BetterTogether::Joatu::Request
      end

      def param_name
        :"joatu_#{super}"
      end

      def resource_params
        super.tap do |attrs|
          attrs[:creator_id] ||= helpers.current_person&.id
        end
      end
    end
  end
end
