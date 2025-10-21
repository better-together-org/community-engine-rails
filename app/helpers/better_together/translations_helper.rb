# frozen_string_literal: true

module BetterTogether
  # Helper methods for translation management views
  module TranslationsHelper
    # Calculate per-locale translation coverage for a specific model
    # This calculates coverage based on actual model instances and their translated attributes
    def calculate_locale_coverage_for_model(_model_name, model_class)
      locale_coverage = {}

      # Get all translatable attributes for this model (including STI descendants)
      all_attributes = collect_model_translatable_attributes(model_class)

      # If no translatable attributes, return structure indicating no translatable content
      if all_attributes.empty?
        I18n.available_locales.each do |locale|
          locale_str = locale.to_s
          locale_coverage[locale_str] = {
            total_attributes: 0,
            translated_attributes: 0,
            missing_attributes: [],
            completion_percentage: 0.0,
            total_instances: 0,
            attribute_details: {},
            has_translatable_attributes: false
          }
        end
        return locale_coverage
      end

      # Get total instances for this model
      total_instances = model_class.count

      # If no instances, return structure showing attributes exist but no data to analyze
      if total_instances == 0
        I18n.available_locales.each do |locale|
          locale_str = locale.to_s
          locale_coverage[locale_str] = {
            total_attributes: all_attributes.length,
            translated_attributes: 0, # No instances means no translations to count
            missing_attributes: all_attributes.keys, # All attributes are "missing" since there's no data
            completion_percentage: 0.0, # 0% since there's no data to translate
            total_instances: 0,
            attribute_details: all_attributes.transform_values do |backend_type|
              {
                backend_type: backend_type,
                translated_count: 0,
                total_instances: 0,
                coverage_percentage: 0.0, # 0% since there are no instances
                no_data: true # Special flag to indicate no data state
              }
            end,
            has_translatable_attributes: true,
            no_data: true # Special flag to indicate this model has no instances
          }
        end
        return locale_coverage
      end

      # Calculate coverage for each available locale
      I18n.available_locales.each do |locale|
        locale_str = locale.to_s

        # Initialize coverage data structure
        locale_coverage[locale_str] = {
          total_attributes: all_attributes.length,
          translated_attributes: 0,
          missing_attributes: [],
          completion_percentage: 0.0,
          total_instances: total_instances,
          attribute_details: {},
          has_translatable_attributes: true
        }

        # Calculate coverage for each translatable attribute
        all_attributes.each do |attribute_name, backend_type|
          translated_count = case backend_type
                             when :string, :text
                               count_string_text_translations(model_class, attribute_name, locale_str)
                             when :action_text
                               count_action_text_translations(model_class, attribute_name, locale_str)
                             when :active_storage
                               count_active_storage_translations(model_class, attribute_name, locale_str)
                             else
                               0
                             end

          # Store detailed attribute information
          locale_coverage[locale_str][:attribute_details][attribute_name] = {
            backend_type: backend_type,
            translated_count: translated_count,
            total_instances: total_instances,
            coverage_percentage: total_instances > 0 ? (translated_count.to_f / total_instances * 100).round(1) : 0.0
          }

          # Consider attribute "translated" if at least one instance has a translation
          if translated_count > 0
            locale_coverage[locale_str][:translated_attributes] += 1
          else
            locale_coverage[locale_str][:missing_attributes] << attribute_name
          end
        end

        # Calculate overall completion percentage for this locale
        next unless locale_coverage[locale_str][:total_attributes] > 0

        locale_coverage[locale_str][:completion_percentage] =
          (locale_coverage[locale_str][:translated_attributes].to_f /
           locale_coverage[locale_str][:total_attributes] * 100).round(1)
      end

      locale_coverage
    end

    # Collect all translatable attributes for a model including backend types
    def collect_model_translatable_attributes(model_class)
      attributes = {}

      # Check base model mobility attributes (align with controller logic)
      if model_class.respond_to?(:mobility_attributes)
        model_class.mobility_attributes.each do |attr|
          # Try to get backend type from mobility config, default to :string
          backend = :string
          if model_class.respond_to?(:mobility) && model_class.mobility.attributes_hash[attr.to_sym]
            backend = model_class.mobility.attributes_hash[attr.to_sym][:backend] || :string
          end
          attributes[attr.to_s] = backend
        end
      end

      # Check Active Storage attachments
      if model_class.respond_to?(:mobility_translated_attachments) && model_class.mobility_translated_attachments&.any?
        model_class.mobility_translated_attachments.each_key do |attachment|
          attributes[attachment.to_s] = :active_storage
        end
      end

      # Check STI descendants (align with controller logic)
      if model_class.respond_to?(:descendants) && model_class.descendants.any?
        model_class.descendants.each do |subclass|
          # Mobility attributes
          if subclass.respond_to?(:mobility_attributes)
            subclass.mobility_attributes.each do |attr|
              # Try to get backend type from mobility config, default to :string
              backend = :string
              if subclass.respond_to?(:mobility) && subclass.mobility.attributes_hash[attr.to_sym]
                backend = subclass.mobility.attributes_hash[attr.to_sym][:backend] || :string
              end
              attributes[attr.to_s] = backend
            end
          end

          # Active Storage attachments
          unless subclass.respond_to?(:mobility_translated_attachments) && subclass.mobility_translated_attachments&.any?
            next
          end

          subclass.mobility_translated_attachments.each_key do |attachment|
            attributes[attachment.to_s] = :active_storage
          end
        end
      end

      attributes
    end

    # Count instances with translations for specific string/text attribute in given locale
    def count_string_text_translations(model_class, attribute_name, locale)
      # Ensure locale is a string, not an array
      locale_str = locale.is_a?(Array) ? locale.first&.to_s : locale.to_s

      model_name = model_class.name
      instance_ids = Set.new

      # Check string translations using Mobility KeyValue backend
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        string_ids = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
                     .where(translatable_type: model_name, key: attribute_name, locale: locale_str)
                     .where.not(value: [nil, '']) # Only count non-empty translations
                     .distinct
                     .pluck(:translatable_id)

        string_ids.each { |id| instance_ids.add(id) }
      end

      # Check text translations using Mobility KeyValue backend
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        text_ids = Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
                   .where(translatable_type: model_name, key: attribute_name, locale: locale_str)
                   .where.not(value: [nil, '']) # Only count non-empty translations
                   .distinct
                   .pluck(:translatable_id)

        text_ids.each { |id| instance_ids.add(id) }
      end

      # Check STI descendants using the same KeyValue approach
      if model_class.respond_to?(:descendants) && model_class.descendants.any?
        model_class.descendants.each do |subclass|
          next unless subclass.respond_to?(:mobility_attributes)

          subclass_name = subclass.name

          # String translations for descendant
          if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
            sub_string_ids = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
                             .where(translatable_type: subclass_name, key: attribute_name, locale: locale_str)
                             .where.not(value: [nil, ''])
                             .distinct
                             .pluck(:translatable_id)

            sub_string_ids.each { |id| instance_ids.add(id) }
          end

          # Text translations for descendant
          next unless defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)

          sub_text_ids = Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
                         .where(translatable_type: subclass_name, key: attribute_name, locale: locale_str)
                         .where.not(value: [nil, ''])
                         .distinct
                         .pluck(:translatable_id)

          sub_text_ids.each { |id| instance_ids.add(id) }
        end
      end

      # Return the count of unique instance IDs
      instance_ids.size
    rescue StandardError => e
      Rails.logger.warn("Error counting string/text translations for #{model_class.name}.#{attribute_name} in #{locale}: #{e.message}")
      0
    end

    # Count instances with translations for specific Action Text attribute in given locale
    def count_action_text_translations(model_class, attribute_name, locale)
      # Ensure locale is a string, not an array
      locale_str = locale.is_a?(Array) ? locale.first&.to_s : locale.to_s

      model_name = model_class.name
      instance_ids = Set.new

      # Check Action Text translations using Mobility KeyValue backend
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        text_ids = Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
                   .where(translatable_type: model_name, key: attribute_name, locale: locale_str)
                   .where.not(value: [nil, '']) # Only count non-empty translations
                   .distinct
                   .pluck(:translatable_id)

        text_ids.each { |id| instance_ids.add(id) }
      end

      # Check STI descendants using the same KeyValue approach
      if model_class.respond_to?(:descendants) && model_class.descendants.any?
        model_class.descendants.each do |subclass|
          next unless subclass.respond_to?(:mobility_attributes)

          subclass_name = subclass.name

          # Action Text translations for descendant
          next unless defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)

          sub_text_ids = Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
                         .where(translatable_type: subclass_name, key: attribute_name, locale: locale_str)
                         .where.not(value: [nil, ''])
                         .distinct
                         .pluck(:translatable_id)

          sub_text_ids.each { |id| instance_ids.add(id) }
        end
      end

      # Return the count of unique instance IDs
      instance_ids.size
    rescue StandardError => e
      Rails.logger.warn("Error counting Action Text translations for #{model_class.name}.#{attribute_name} in #{locale}: #{e.message}")
      0
    end

    # Count instances with translations for specific Active Storage attachment in given locale
    def count_active_storage_translations(model_class, attachment_name, locale)
      # Ensure locale is a string, not an array
      locale_str = locale.is_a?(Array) ? locale.first&.to_s : locale.to_s

      model_name = model_class.name
      instance_ids = Set.new

      # Active Storage attachments typically use string translations for metadata
      # Check string translations using Mobility KeyValue backend
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
        string_ids = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
                     .where(translatable_type: model_name, key: attachment_name, locale: locale_str)
                     .where.not(value: [nil, '']) # Only count non-empty translations
                     .distinct
                     .pluck(:translatable_id)

        string_ids.each { |id| instance_ids.add(id) }
      end

      # Also check text translations in case attachments have longer metadata
      if defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)
        text_ids = Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
                   .where(translatable_type: model_name, key: attachment_name, locale: locale_str)
                   .where.not(value: [nil, ''])
                   .distinct
                   .pluck(:translatable_id)

        text_ids.each { |id| instance_ids.add(id) }
      end

      # Check STI descendants using the same KeyValue approach
      if model_class.respond_to?(:descendants) && model_class.descendants.any?
        model_class.descendants.each do |subclass|
          next unless subclass.respond_to?(:mobility_attributes)

          subclass_name = subclass.name

          # String translations for descendant
          if defined?(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation)
            sub_string_ids = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
                             .where(translatable_type: subclass_name, key: attachment_name, locale: locale_str)
                             .where.not(value: [nil, ''])
                             .distinct
                             .pluck(:translatable_id)

            sub_string_ids.each { |id| instance_ids.add(id) }
          end

          # Text translations for descendant
          next unless defined?(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation)

          sub_text_ids = Mobility::Backends::ActiveRecord::KeyValue::TextTranslation
                         .where(translatable_type: subclass_name, key: attachment_name, locale: locale_str)
                         .where.not(value: [nil, ''])
                         .distinct
                         .pluck(:translatable_id)

          sub_text_ids.each { |id| instance_ids.add(id) }
        end
      end

      # Return the count of unique instance IDs
      instance_ids.size
    rescue StandardError => e
      Rails.logger.warn("Error counting Active Storage translations for #{model_class.name}.#{attachment_name} in #{locale}: #{e.message}")
      0
    end
  end
end
