# frozen_string_literal: true

module BetterTogether
  module Geography
    # Search behind the address form's country, state and settlement selects. Each level can be narrowed by
    # the level above it (states by country, settlements by state or country), and searches match the name in
    # any locale. Results are capped by the caller.
    class AddressLookup
      LEVELS = {
        'country' => BetterTogether::Geography::Country,
        'state' => BetterTogether::Geography::State,
        'settlement' => BetterTogether::Geography::Settlement
      }.freeze

      UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

      def self.level?(level)
        LEVELS.key?(level.to_s)
      end

      def initialize(level:, search: nil, country_id: nil, state_id: nil)
        @klass = LEVELS.fetch(level.to_s)
        @search = search.to_s.strip
        # A parent select holding typed text sends that text, not an id; it narrows nothing.
        @country_id = uuid_or_nil(country_id)
        @state_id = uuid_or_nil(state_id)
      end

      def scope
        relation = @klass.i18n
        relation = relation.where(country_id: @country_id) if @country_id && @klass.column_names.include?('country_id')
        relation = relation.where(state_id: @state_id) if @state_id && @klass.column_names.include?('state_id')
        relation = relation.where(id: matching_ids) if @search.present?
        relation.order(:name)
      end

      private

      def uuid_or_nil(value)
        value.to_s.match?(UUID_FORMAT) ? value.to_s : nil
      end

      def matching_ids
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@search)}%"

        @klass.unscoped.joins(name_join).where(translations[:value].matches(pattern)).select(:id)
      end

      def translations
        @translations ||= Arel::Table.new(:mobility_string_translations)
      end

      def name_join
        @klass.arel_table.join(translations).on(name_translation_match).join_sources
      end

      def name_translation_match
        translations[:translatable_type].eq(@klass.base_class.name)
                                        .and(translations[:translatable_id].eq(@klass.arel_table[:id]))
                                        .and(translations[:key].eq('name'))
      end
    end
  end
end
