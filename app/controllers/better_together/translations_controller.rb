# frozen_string_literal: true

module BetterTogether
  class TranslationsController < ApplicationController # rubocop:todo Style/Documentation
    def index
      # For overview tab - prepare statistics data
      @available_locales = I18n.available_locales.map(&:to_s)
      @available_model_types = collect_all_model_types
      @available_attributes = collect_available_attributes('all')

      @data_type_summary = build_data_type_summary
      @data_type_stats = calculate_data_type_stats

      # Calculate overview statistics
      @locale_stats = calculate_locale_stats
      @model_type_stats = calculate_model_type_stats
      @attribute_stats = calculate_attribute_stats
      @total_translation_records = calculate_total_records

      # Calculate model instance translation coverage
      @model_instance_stats = calculate_model_instance_stats
    end

    def by_locale
      @page = params[:page] || 1

      # Safely process locale parameter with comprehensive validation
      begin
        raw_locale = params[:locale] || I18n.available_locales.first.to_s
        @locale_filter = raw_locale.to_s.downcase.strip
        @available_locales = I18n.available_locales.map(&:to_s)

        # Ensure the locale_filter is valid
        @locale_filter = I18n.available_locales.first.to_s unless @available_locales.include?(@locale_filter)

        # Validate with I18n to ensure it doesn't cause issues
        I18n.with_locale(@locale_filter) { I18n.t('hello') }
      rescue I18n::InvalidLocale => e
        Rails.logger.warn("Invalid locale encountered: #{raw_locale} - #{e.message}")
        @locale_filter = I18n.available_locales.first.to_s
      end

      translation_records = fetch_translation_records_by_locale(@locale_filter)
      @translations = Kaminari.paginate_array(translation_records).page(@page).per(100)

      respond_to do |format|
        format.html { render partial: 'by_locale' }
      end
    end

    def by_model_type
      @page = params[:page] || 1
      @model_type_filter = params[:model_type] || @available_model_types&.first&.dig(:name)
      @available_model_types = collect_all_model_types

      translation_records = fetch_translation_records_by_model_type(@model_type_filter)
      @translations = Kaminari.paginate_array(translation_records).page(@page).per(100)

      respond_to do |format|
        format.html { render partial: 'by_model_type' }
      end
    end

    def by_data_type
      @page = params[:page] || 1
      @data_type_filter = params[:data_type] || 'string'
      @available_data_types = %w[string text rich_text file]

      translation_records = fetch_translation_records_by_data_type(@data_type_filter)
      @translations = Kaminari.paginate_array(translation_records).page(@page).per(100)

      respond_to do |format|
        format.html { render partial: 'by_data_type' }
      end
    end

    def by_attribute
      @page = params[:page] || 1
      @attribute_filter = params[:attribute] || 'name'
      @available_attributes = collect_all_attributes

      translation_records = fetch_translation_records_by_attribute(@attribute_filter)
      @translations = Kaminari.paginate_array(translation_records).page(@page).per(100)

      respond_to do |format|
        format.html { render partial: 'by_attribute' }
      end
    end

    private

    def collect_all_model_types
      model_types = Set.new

      # Collect from all translation backends
      collect_string_translation_models(model_types)
      collect_text_translation_models(model_types)
      collect_rich_text_translation_models(model_types)
      collect_file_translation_models(model_types)

      # Convert to array and constantize
      model_types.map do |type_name|
        { name: type_name, class: type_name.constantize }
      rescue StandardError => e
        Rails.logger.warn "Could not constantize model type #{type_name}: #{e.message}"
        nil
      end.compact.sort_by { |type| type[:name] }
    end

    def collect_available_attributes(model_filter = 'all')
      return [] if model_filter == 'all'

      model_class = model_filter.constantize
      attributes = []

      # Add mobility attributes
      if model_class.respond_to?(:mobility_attributes)
        model_class.mobility_attributes.each do |attr|
          attributes << { name: attr.to_s, type: 'text', source: 'mobility' }
        end
      end

      # Add translatable attachment attributes
      if model_class.respond_to?(:mobility_translated_attachments)
        model_class.mobility_translated_attachments&.keys&.each do |attr|
          attributes << { name: attr.to_s, type: 'file', source: 'attachment' }
        end
      end

      attributes.sort_by { |attr| attr[:name] }
    rescue StandardError => e
      Rails.logger.error "Error collecting attributes for #{model_filter}: #{e.message}"
      []
    end

    def fetch_translation_records
      records = []

      # Apply model type filter
      model_types = if @model_type_filter == 'all'
                      @available_model_types.map { |mt| mt[:name] }
                    else
                      [@model_type_filter]
                    end

      model_types.each do |model_type|
        # Fetch string/text translations
        records.concat(fetch_key_value_translations(model_type, 'string'))
        records.concat(fetch_key_value_translations(model_type, 'text'))
        # Fetch rich text translations
        records.concat(fetch_rich_text_translations(model_type))
        # Fetch file translations
        records.concat(fetch_file_translations(model_type))
      end

      # Apply additional filters
      records = apply_locale_filter(records)
      records = apply_data_type_filter(records)
      records = apply_attribute_filter(records)

      records.sort_by { |r| [r[:translatable_type], r[:translatable_id], r[:key]] }
    end

    def fetch_key_value_translations(model_type, data_type)
      return [] unless translation_class_exists?(data_type)

      translation_class = get_translation_class(data_type)
      translations = translation_class.where(translatable_type: model_type)

      translations.map do |translation|
        {
          id: translation.id,
          translatable_type: translation.translatable_type,
          translatable_id: translation.translatable_id,
          key: translation.key,
          locale: translation.locale,
          value: translation.value,
          data_type: data_type,
          source: 'mobility'
        }
      end
    end

    def fetch_rich_text_translations(model_type)
      return [] unless defined?(ActionText::RichText)

      rich_texts = ActionText::RichText.where(record_type: model_type)

      rich_texts.map do |rich_text|
        {
          id: rich_text.id,
          translatable_type: rich_text.record_type,
          translatable_id: rich_text.record_id,
          key: rich_text.name,
          locale: rich_text.locale,
          value: rich_text.body.to_s.truncate(100),
          data_type: 'rich_text',
          source: 'action_text'
        }
      end
    end

    def fetch_file_translations(model_type)
      return [] unless defined?(ActiveStorage::Attachment) &&
                       ActiveStorage::Attachment.column_names.include?('locale')

      attachments = ActiveStorage::Attachment.where(record_type: model_type)

      attachments.map do |attachment|
        {
          id: attachment.id,
          translatable_type: attachment.record_type,
          translatable_id: attachment.record_id,
          key: attachment.name,
          locale: attachment.locale,
          value: attachment.filename.to_s,
          data_type: 'file',
          source: 'active_storage'
        }
      end
    end

    def apply_locale_filter(records)
      return records if @locale_filter == 'all'

      records.select { |record| record[:locale] == @locale_filter }
    end

    def apply_data_type_filter(records)
      return records if @data_type_filter == 'all'

      records.select { |record| record[:data_type] == @data_type_filter }
    end

    def apply_attribute_filter(records)
      return records if @attribute_filter == 'all'

      # Handle multiple attributes (comma-separated)
      selected_attributes = @attribute_filter.split(',').map(&:strip)
      records.select { |record| selected_attributes.include?(record[:key]) }
    end

    def translation_class_exists?(data_type)
      case data_type
      when 'string'
        defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
      when 'text'
        defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
      else
        false
      end
    end

    def get_translation_class(data_type)
      case data_type
      when 'string'
        Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
      when 'text'
        Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
      end
    end

    def find_translated_models(data_type_filter = 'all')
      model_types = Set.new

      # Collect models from each translation backend based on data type filter
      case data_type_filter
      when 'string'
        collect_string_translation_models(model_types)
      when 'text'
        collect_text_translation_models(model_types)
      when 'rich_text'
        collect_rich_text_translation_models(model_types)
      when 'file'
        collect_file_translation_models(model_types)
      else # 'all'
        collect_string_translation_models(model_types)
        collect_text_translation_models(model_types)
        collect_rich_text_translation_models(model_types)
        collect_file_translation_models(model_types)
      end

      # Convert to array, constantize, and sort
      model_types = model_types.map(&:constantize).sort_by(&:name)

      # Filter to only include models with mobility_attributes or translatable attachments
      model_types.select do |model|
        model.respond_to?(:mobility_attributes) ||
          model.respond_to?(:mobility_translated_attachments)
      end
    rescue StandardError => e
      Rails.logger.error "Error finding translated models: #{e.message}"
      []
    end

    def collect_string_translation_models(model_types)
      return unless defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)

      Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
        .distinct
        .pluck(:translatable_type)
        .each { |type| model_types.add(type) }
    end

    def collect_text_translation_models(model_types)
      return unless defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)

      Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
        .distinct
        .pluck(:translatable_type)
        .each { |type| model_types.add(type) }
    end

    def collect_rich_text_translation_models(model_types)
      return unless defined?(ActionText::RichText)

      ActionText::RichText
        .distinct
        .pluck(:record_type)
        .each { |type| model_types.add(type) }
    end

    def collect_file_translation_models(model_types)
      return unless defined?(ActiveStorage::Attachment) &&
                    ActiveStorage::Attachment.column_names.include?('locale')

      ActiveStorage::Attachment
        .distinct
        .pluck(:record_type)
        .each { |type| model_types.add(type) }
    end

    def group_models_by_namespace(models)
      grouped = models.group_by do |model|
        # Extract namespace from class name (e.g., "BetterTogether::Community" -> "BetterTogether")
        model.name.include?('::') ? model.name.split('::').first : 'Base'
      end

      # Sort namespaces and models within each namespace
      grouped.transform_values { |models_in_namespace| models_in_namespace.sort_by(&:name) }
             .sort_by { |namespace, _| namespace }
             .to_h
    end

    def build_data_type_summary
      {
        string: {
          description: 'Short text fields stored in mobility_string_translations table',
          storage_table: 'mobility_string_translations',
          backend: 'Mobility::Backends::ActiveRecord::KeyValue::StringTranslation'
        },
        text: {
          description: 'Long text fields stored in mobility_text_translations table',
          storage_table: 'mobility_text_translations',
          backend: 'Mobility::Backends::ActiveRecord::KeyValue::TextTranslation'
        },
        rich_text: {
          description: 'Rich text content with formatting stored via ActionText',
          storage_table: 'action_text_rich_texts',
          backend: 'ActionText::RichText'
        },
        file: {
          description: 'File attachments with locale support via ActiveStorage',
          storage_table: 'active_storage_attachments (with locale column)',
          backend: 'ActiveStorage::Attachment with locale'
        }
      }
    end

    def calculate_data_type_stats
      stats = {}

      # String translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        stats[:string] = {
          total_records: Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.count,
          unique_models: Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.distinct.count(:translatable_type)
        }
      end

      # Text translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        stats[:text] = {
          total_records: Mobility::Backends::ActiveRecord::KeyValue::TextTranslation.count,
          unique_models: Mobility::Backends::ActiveRecord::KeyValue::TextTranslation.distinct.count(:translatable_type)
        }
      end

      # Rich text translations
      if defined?(ActionText::RichText)
        stats[:rich_text] = {
          total_records: ActionText::RichText.count,
          unique_models: ActionText::RichText.distinct.count(:record_type)
        }
      end

      # File translations
      if defined?(ActiveStorage::Attachment) && ActiveStorage::Attachment.column_names.include?('locale')
        stats[:file] = {
          total_records: ActiveStorage::Attachment.count,
          unique_models: ActiveStorage::Attachment.distinct.count(:record_type)
        }
      end

      stats
    end

    def calculate_translation_stats(models)
      return {} if models.empty?

      stats = {}

      models.each do |model|
        stats[model.name] = {}

        @available_locales.each do |locale|
          # Count total records and translated records for this model and locale
          total_records = begin
            model.count
          rescue StandardError
            0
          end

          translated_count = count_translated_records(model, locale)

          stats[model.name][locale] = {
            total: total_records,
            translated: translated_count,
            percentage: total_records > 0 ? ((translated_count.to_f / total_records) * 100).round(1) : 0
          }
        end
      end

      stats
    end

    def count_translated_records(model, locale)
      # Apply locale filter if specified
      return 0 if @locale_filter != 'all' && @locale_filter != locale

      count = 0

      # Count string translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        count += Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
                 .where(translatable_type: model.name, locale: locale)
                 .distinct(:translatable_id)
                 .count
      end

      # Count text translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        count += Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
                 .where(translatable_type: model.name, locale: locale)
                 .distinct(:translatable_id)
                 .count
      end

      # Count rich text translations (ActionText uses different structure)
      if defined?(ActionText::RichText)
        count += ActionText::RichText
                 .where(record_type: model.name, locale: locale)
                 .distinct(:record_id)
                 .count
      end

      # Count file translations
      if defined?(ActiveStorage::Attachment) && ActiveStorage::Attachment.column_names.include?('locale')
        count += ActiveStorage::Attachment
                 .where(record_type: model.name, locale: locale)
                 .distinct(:record_id)
                 .count
      end

      count
    end

    def translate
      content = params[:content]
      source_locale = params[:source_locale]
      target_locale = params[:target_locale]
      initiator = helpers.current_person

      translation_job = BetterTogether::TranslationJob.perform_later(
        content, source_locale, target_locale, initiator
      )
      render json: { success: true, job_id: translation_job.job_id }
    end

    # Statistical calculation methods for overview
    def calculate_locale_stats
      stats = {}

      I18n.available_locales.each do |locale|
        count = 0

        if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
          count += Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(locale: locale).count
        end

        if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
          count += Mobility::Backends::ActiveRecord::KeyValue::TextTranslation.where(locale: locale).count
        end

        count += ActionText::RichText.where(locale: locale).count if defined?(ActionText::RichText)

        count += ActiveStorage::Attachment.where(locale: locale).count if defined?(ActiveStorage::Attachment)

        stats[locale] = count if count.positive?
      end

      stats.sort_by { |_, count| -count }.to_h
    end

    def calculate_model_type_stats
      stats = {}

      # Collect from string translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
          .group(:translatable_type)
          .count
          .each { |type, count| stats[type] = (stats[type] || 0) + count }
      end

      # Collect from text translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
          .group(:translatable_type)
          .count
          .each { |type, count| stats[type] = (stats[type] || 0) + count }
      end

      # Collect from rich text translations
      if defined?(ActionText::RichText)
        ActionText::RichText
          .group(:record_type)
          .count
          .each { |type, count| stats[type] = (stats[type] || 0) + count }
      end

      # Collect from file translations
      if defined?(ActiveStorage::Attachment)
        ActiveStorage::Attachment
          .group(:record_type)
          .count
          .each { |type, count| stats[type] = (stats[type] || 0) + count }
      end

      stats.sort_by { |_, count| -count }.to_h
    end

    def calculate_attribute_stats
      stats = {}

      # Collect from string translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
          .group(:key)
          .count
          .each { |key, count| stats[key] = (stats[key] || 0) + count }
      end

      # Collect from text translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
          .group(:key)
          .count
          .each { |key, count| stats[key] = (stats[key] || 0) + count }
      end

      # Collect from rich text translations
      if defined?(ActionText::RichText)
        ActionText::RichText
          .group(:name)
          .count
          .each { |name, count| stats[name] = (stats[name] || 0) + count }
      end

      # NOTE: File translations don't have a key/name field in the same way

      stats.sort_by { |_, count| -count }.to_h
    end

    def calculate_total_records
      count = 0

      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        count += Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.count
      end

      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        count += Mobility::Backends::ActiveRecord::KeyValue::TextTranslation.count
      end

      count += ActionText::RichText.count if defined?(ActionText::RichText)

      count += ActiveStorage::Attachment.count if defined?(ActiveStorage::Attachment)

      count
    end

    # Calculate unique model instance translation coverage
    def calculate_model_instance_stats
      stats = {}

      @available_model_types.each do |model_type|
        model_name = model_type[:name]
        next unless model_name

        begin
          model_class = model_name.constantize

          # Count only active instances (handle soft deletes if present)
          total_instances = if model_class.respond_to?(:without_deleted)
                              model_class.without_deleted.count
                            elsif model_class.respond_to?(:with_deleted)
                              model_class.all.count # Paranoia gem - count without deleted
                            else
                              model_class.count
                            end

          # Get instances with any translations
          translated_instances = calculate_translated_instance_count(model_name)

          # Get attribute-specific coverage
          attribute_coverage = calculate_attribute_coverage_for_model(model_name, model_class)

          # Calculate coverage percentage with bounds checking
          coverage_percentage = if total_instances.positive? && translated_instances <= total_instances
                                  (translated_instances.to_f / total_instances * 100).round(1)
                                elsif translated_instances > total_instances
                                  Rails.logger.warn "Translation coverage anomaly for #{model_name}: #{translated_instances} translated > #{total_instances} total"
                                  100.0 # Cap at 100% if there's a data inconsistency
                                else
                                  0.0
                                end

          stats[model_name] = {
            total_instances: total_instances,
            translated_instances: translated_instances,
            translation_coverage: coverage_percentage,
            attribute_coverage: attribute_coverage
          }
        rescue StandardError => e
          Rails.logger.warn "Error calculating model instance stats for #{model_name}: #{e.message}"
        end
      end

      stats.sort_by { |_, data| -data[:translated_instances] }.to_h
    end

    def calculate_translated_instance_count(model_name)
      instance_ids = Set.new

      # Collect translated instance IDs from string translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
          .where(translatable_type: model_name)
          .where.not(value: [nil, ''])  # Only count non-empty translations
          .where.not(locale: [nil, '']) # Only count valid locales
          .distinct
          .pluck(:translatable_id)
          .each { |id| instance_ids.add(id) }
      end

      # Collect from text translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
          .where(translatable_type: model_name)
          .where.not(value: [nil, ''])  # Only count non-empty translations
          .where.not(locale: [nil, '']) # Only count valid locales
          .distinct
          .pluck(:translatable_id)
          .each { |id| instance_ids.add(id) }
      end

      # Collect from rich text translations
      if defined?(ActionText::RichText)
        ActionText::RichText
          .where(record_type: model_name)
          .where.not(body: [nil, ''])   # Only count non-empty rich text
          .where.not(locale: [nil, '']) # Only count valid locales
          .distinct
          .pluck(:record_id)
          .each { |id| instance_ids.add(id) }
      end

      # Collect from file translations
      if defined?(ActiveStorage::Attachment) && ActiveStorage::Attachment.column_names.include?('locale')
        ActiveStorage::Attachment
          .where(record_type: model_name)
          .where.not(locale: [nil, '']) # Only count attachments with explicit locales
          .distinct
          .pluck(:record_id)
          .each { |id| instance_ids.add(id) }
      end

      # Validate that these instance IDs actually exist as active records
      return 0 if instance_ids.empty?

      begin
        model_class = model_name.constantize
        existing_ids = if model_class.respond_to?(:without_deleted)
                         model_class.without_deleted.where(id: instance_ids.to_a).pluck(:id)
                       else
                         model_class.where(id: instance_ids.to_a).pluck(:id)
                       end
        existing_ids.count
      rescue StandardError => e
        Rails.logger.warn "Error validating translated instances for #{model_name}: #{e.message}"
        instance_ids.count # Fallback to original count
      end
    end

    def calculate_attribute_coverage_for_model(model_name, model_class)
      coverage = {}

      # Calculate total instances once (handle soft deletes)
      total_instances = if model_class.respond_to?(:without_deleted)
                          model_class.without_deleted.count
                        elsif model_class.respond_to?(:with_deleted)
                          model_class.all.count
                        else
                          model_class.count
                        end

      # Get all mobility attributes for this model
      if model_class.respond_to?(:mobility_attributes)
        model_class.mobility_attributes.each do |attribute|
          attribute_name = attribute.to_s

          # Count instances with translations for this specific attribute
          instances_with_attribute = count_instances_with_attribute_translations(model_name, attribute_name)

          # Calculate coverage with bounds checking
          coverage_percentage = if total_instances.positive? && instances_with_attribute <= total_instances
                                  (instances_with_attribute.to_f / total_instances * 100).round(1)
                                elsif instances_with_attribute > total_instances
                                  Rails.logger.warn "Attribute coverage anomaly for #{model_name}.#{attribute_name}: #{instances_with_attribute} > #{total_instances}"
                                  100.0
                                else
                                  0.0
                                end

          coverage[attribute_name] = {
            instances_translated: instances_with_attribute,
            total_instances: total_instances,
            coverage_percentage: coverage_percentage,
            attribute_type: 'mobility'
          }
        end
      end

      # Get translatable attachment attributes
      if model_class.respond_to?(:mobility_translated_attachments)
        model_class.mobility_translated_attachments&.keys&.each do |attachment_name|
          attachment_name = attachment_name.to_s

          # Count instances with file translations for this attachment
          instances_with_attachment = count_instances_with_file_translations(model_name, attachment_name)

          # Calculate coverage with bounds checking
          coverage_percentage = if total_instances.positive? && instances_with_attachment <= total_instances
                                  (instances_with_attachment.to_f / total_instances * 100).round(1)
                                elsif instances_with_attachment > total_instances
                                  Rails.logger.warn "File coverage anomaly for #{model_name}.#{attachment_name}: #{instances_with_attachment} > #{total_instances}"
                                  100.0
                                else
                                  0.0
                                end

          coverage[attachment_name] = {
            instances_translated: instances_with_attachment,
            total_instances: total_instances,
            coverage_percentage: coverage_percentage,
            attribute_type: 'file'
          }
        end
      end

      coverage.sort_by { |_, data| -data[:instances_translated] }.to_h
    end

    def count_instances_with_attribute_translations(model_name, attribute_name)
      instance_ids = Set.new

      # Check string translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
          .where(translatable_type: model_name, key: attribute_name)
          .where.not(value: [nil, ''])  # Only count non-empty translations
          .where.not(locale: [nil, '']) # Only count valid locales
          .distinct
          .pluck(:translatable_id)
          .each { |id| instance_ids.add(id) }
      end

      # Check text translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
          .where(translatable_type: model_name, key: attribute_name)
          .where.not(value: [nil, ''])  # Only count non-empty translations
          .where.not(locale: [nil, '']) # Only count valid locales
          .distinct
          .pluck(:translatable_id)
          .each { |id| instance_ids.add(id) }
      end

      # Check rich text translations (ActionText uses 'name' field)
      if defined?(ActionText::RichText)
        ActionText::RichText
          .where(record_type: model_name, name: attribute_name)
          .where.not(body: [nil, ''])   # Only count non-empty rich text
          .where.not(locale: [nil, '']) # Only count valid locales
          .distinct
          .pluck(:record_id)
          .each { |id| instance_ids.add(id) }
      end

      # Validate that these instance IDs actually exist as active records
      return 0 if instance_ids.empty?

      begin
        model_class = model_name.constantize
        existing_ids = if model_class.respond_to?(:without_deleted)
                         model_class.without_deleted.where(id: instance_ids.to_a).pluck(:id)
                       else
                         model_class.where(id: instance_ids.to_a).pluck(:id)
                       end
        existing_ids.count
      rescue StandardError => e
        Rails.logger.warn "Error validating attribute translated instances for #{model_name}: #{e.message}"
        instance_ids.count # Fallback to original count
      end
    end

    def count_instances_with_file_translations(model_name, attachment_name)
      return 0 unless defined?(ActiveStorage::Attachment) &&
                      ActiveStorage::Attachment.column_names.include?('locale')

      ActiveStorage::Attachment
        .where(record_type: model_name, name: attachment_name)
        .where.not(locale: [nil, ''])
        .distinct
        .count(:record_id)
    end

    # Fetch methods for new tab views
    def fetch_translation_records_by_locale(locale)
      records = []

      # String translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
          .includes(:translatable)
          .where(locale: locale)
          .where.not(value: [nil, ''])
          .find_each do |record|
            records << format_translation_record(record, 'string')
          end
      end

      # Text translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
          .includes(:translatable)
          .where(locale: locale)
          .where.not(value: [nil, ''])
          .find_each do |record|
            records << format_translation_record(record, 'text')
          end
      end

      # Rich text translations
      if defined?(ActionText::RichText)
        ActionText::RichText
          .includes(:record)
          .where(locale: locale)
          .where.not(body: [nil, ''])
          .find_each do |record|
            records << format_rich_text_record(record)
          end
      end

      records.sort_by { |r| [r[:model_type], r[:translatable_id], r[:attribute]] }
    end

    def fetch_translation_records_by_model_type(model_type)
      return [] unless model_type

      records = []

      # String translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
          .includes(:translatable)
          .where(translatable_type: model_type)
          .where.not(value: [nil, ''])
          .find_each do |record|
            records << format_translation_record(record, 'string')
          end
      end

      # Text translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
          .includes(:translatable)
          .where(translatable_type: model_type)
          .where.not(value: [nil, ''])
          .find_each do |record|
            records << format_translation_record(record, 'text')
          end
      end

      # Rich text translations
      if defined?(ActionText::RichText)
        ActionText::RichText
          .includes(:record)
          .where(record_type: model_type)
          .where.not(body: [nil, ''])
          .find_each do |record|
            records << format_rich_text_record(record)
          end
      end

      records.sort_by { |r| [r[:locale], r[:translatable_id], r[:attribute]] }
    end

    def fetch_translation_records_by_data_type(data_type)
      records = []

      case data_type
      when 'string'
        if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
          Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
            .includes(:translatable)
            .where.not(value: [nil, ''])
            .find_each do |record|
              records << format_translation_record(record, 'string')
            end
        end
      when 'text'
        if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
          Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
            .includes(:translatable)
            .where.not(value: [nil, ''])
            .find_each do |record|
              records << format_translation_record(record, 'text')
            end
        end
      when 'rich_text'
        if defined?(ActionText::RichText)
          ActionText::RichText
            .includes(:record)
            .where.not(body: [nil, ''])
            .find_each do |record|
              records << format_rich_text_record(record)
            end
        end
      when 'file'
        if defined?(ActiveStorage::Attachment) && ActiveStorage::Attachment.column_names.include?('locale')
          ActiveStorage::Attachment
            .includes(:record)
            .where.not(locale: [nil, ''])
            .find_each do |record|
              records << format_file_record(record)
            end
        end
      end

      records.sort_by { |r| [r[:model_type], r[:locale], r[:translatable_id]] }
    end

    def fetch_translation_records_by_attribute(attribute_name)
      return [] unless attribute_name

      records = []

      # String translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
          .includes(:translatable)
          .where(key: attribute_name)
          .where.not(value: [nil, ''])
          .find_each do |record|
            records << format_translation_record(record, 'string')
          end
      end

      # Text translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
          .includes(:translatable)
          .where(key: attribute_name)
          .where.not(value: [nil, ''])
          .find_each do |record|
            records << format_translation_record(record, 'text')
          end
      end

      # Rich text translations
      if defined?(ActionText::RichText)
        ActionText::RichText
          .includes(:record)
          .where(name: attribute_name)
          .where.not(body: [nil, ''])
          .find_each do |record|
            records << format_rich_text_record(record)
          end
      end

      records.sort_by { |r| [r[:model_type], r[:locale], r[:translatable_id]] }
    end

    def collect_all_attributes
      attributes = Set.new

      # Collect from string translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
          .distinct
          .pluck(:key)
          .each { |attr| attributes.add(attr) }
      end

      # Collect from text translations
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
          .distinct
          .pluck(:key)
          .each { |attr| attributes.add(attr) }
      end

      # Collect from rich text translations
      if defined?(ActionText::RichText)
        ActionText::RichText
          .distinct
          .pluck(:name)
          .each { |attr| attributes.add(attr) }
      end

      attributes.to_a.sort
    end

    def format_translation_record(record, data_type)
      {
        id: record.id,
        translatable_type: record.translatable_type,
        translatable_id: record.translatable_id,
        attribute: record.key,
        locale: record.locale,
        data_type: data_type,
        value: truncate_value(record.value),
        full_value: record.value,
        model_type: record.translatable_type&.split('::')&.last || record.translatable_type
      }
    end

    def format_rich_text_record(record)
      {
        id: record.id,
        translatable_type: record.record_type,
        translatable_id: record.record_id,
        attribute: record.name,
        locale: record.locale,
        data_type: 'rich_text',
        value: truncate_value(record.body.to_plain_text),
        full_value: record.body.to_s,
        model_type: record.record_type&.split('::')&.last || record.record_type
      }
    end

    def format_file_record(record)
      {
        id: record.id,
        translatable_type: record.record_type,
        translatable_id: record.record_id,
        attribute: record.name,
        locale: record.locale,
        data_type: 'file',
        value: record.filename.to_s,
        full_value: record.filename.to_s,
        model_type: record.record_type&.split('::')&.last || record.record_type
      }
    end

    def truncate_value(value, limit = 100)
      return '' if value.nil?

      text = value.to_s.strip
      text.length > limit ? "#{text[0..limit]}..." : text
    end
  end
end
