# frozen_string_literal: true

module BetterTogether
  module Host
    class TranslationManagementController < ApplicationController # rubocop:todo Style/Documentation
      def show
        authorize [:host_dashboard], :show?, policy_class: HostDashboardPolicy

        @dashboard_scope = 'readonly'
        @backend_stats = build_backend_stats
        @locale_stats = aggregate_counts_by(:locale).first(8)
        @translatable_type_stats = aggregate_counts_by(:translatable_type).first(8)
        @recovery_slices = %w[
          locale-normalization
          translation-indexes
          dashboard-namespace
          readonly-dashboard
          dashboard-tests
        ]
      end

      private

      def build_backend_stats
        [
          backend_stat(:string, Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.all, :translatable_type),
          backend_stat(:text, Mobility::Backends::ActiveRecord::KeyValue::TextTranslation.all, :translatable_type),
          backend_stat(:rich_text, ActionText::RichText.all, :record_type),
          backend_stat(:file, translated_attachments, :record_type)
        ]
      end

      def backend_stat(key, relation, type_column)
        {
          key:,
          record_count: relation.count,
          model_count: relation.distinct.count(type_column)
        }
      end

      def aggregate_counts_by(group_field)
        counts = Hash.new(0)

        translation_relations_for(group_field).each do |relation|
          relation.group(group_field).count.each do |key, count|
            counts[key.to_s] += count
          end
        end

        counts.sort_by { |_key, count| -count }
      end

      def translation_relations_for(group_field)
        [
          Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.all,
          Mobility::Backends::ActiveRecord::KeyValue::TextTranslation.all,
          ActionText::RichText.all,
          translated_attachments
        ].select { |relation| relation.klass.column_names.include?(group_field.to_s) }
      end

      def translated_attachments
        return ActiveStorage::Attachment.none unless ActiveStorage::Attachment.column_names.include?('locale')

        ActiveStorage::Attachment.all
      end
    end
  end
end
