# frozen_string_literal: true

module BetterTogether
  # Abstracts the retrieval of resources that use friendly IDs
  class FriendlyResourceController < ResourceController
    helper_method :resource_class

    protected

    def find_by_translatable(translatable_type: resource_class.name, friendly_id: id_param)
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
    rescue ActiveRecord::RecordNotFound => e
      # 2. By friendly on all available locales
      @resource ||= find_by_translatable

      raise e if @resource.nil?

      @resource
    end
  end
end
