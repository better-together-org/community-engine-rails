# frozen_string_literal: true

module BetterTogether
  # Abstracts the retrieval of resources that use friendly IDs
  class FriendlyResourceController < ResourceController
    before_action :set_metric_viewable, only: :show

    protected

    def find_by_translatable(translatable_type: translatable_resource_type, friendly_id: id_param)
      Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(
        translatable_type:,
        key: 'slug',
        value: friendly_id,
        locale: I18n.available_locales
      ).includes(:translatable).last&.translatable
    end

    # Fallback to find resource by slug translations when not found in current locale
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    def set_resource_instance # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      # 1. Try translated slug lookup across locales to avoid DB-specific issues with friendly_id history
      @resource ||= find_by_translatable

      # rubocop:todo Layout/LineLength
      # 2. Try Mobility translation lookup across all locales when available (safer than raw SQL on mobility_string_translations)
      # rubocop:enable Layout/LineLength
      if @resource.nil? && resource_class.respond_to?(:i18n)
        translation = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(
          translatable_type: resource_class.name,
          key: 'slug',
          value: id_param
        ).includes(:translatable).first

        @resource ||= translation&.translatable
      end

      # 3. Fallback to friendly_id lookup (may use history) if not found via translations
      if @resource.nil?
        begin
          @resource = resource_collection.friendly.find(id_param)
        rescue StandardError
          # 4. Final fallback: direct find by id
          @resource = resource_collection.find_by(id: id_param)
        end
      end

      render_not_found && return if @resource.nil?

      @resource
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    def translatable_resource_type
      resource_class.name
    end

    def set_metric_viewable
      self.metric_viewable = resource_instance
    end
  end
end
