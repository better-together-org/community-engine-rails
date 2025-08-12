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
    def set_resource_instance
      @resource ||= resource_collection.friendly.find(id_param)
    rescue ActiveRecord::RecordNotFound
      # 2. By friendly on all available locales
      @resource ||= find_by_translatable

      render_not_found && return if @resource.nil?

      @resource
    end

    def translatable_resource_type
      resource_class.name
    end

    def set_metric_viewable
      self.metric_viewable = resource_instance
    end
  end
end
