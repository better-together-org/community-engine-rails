# frozen_string_literal: true

module BetterTogether
  # Abstracts the retrieval of resources that use friendly IDs
  class FriendlyResourceController < ResourceController
    before_action :set_metric_viewable, only: :show

    protected

    # Scoped by default to resource_collection's ids (policy_scope, itself
    # platform-scoped for platform-scoped resource types) so a slug that's
    # reused across two different platforms (allowed — slug uniqueness is
    # scoped to platform_id, not global) can't resolve to the wrong platform's
    # record.
    #
    # Pass `collection:` explicitly when looking up a translatable_type that
    # differs from this controller's own resource_class (e.g.
    # NavigationItemsController resolving its parent NavigationArea) —
    # resource_collection is scoped to THIS controller's resource_class, so
    # reusing it for an unrelated model's slug lookup would restrict
    # translatable_id to the wrong table's ids and never match.
    def find_by_translatable(translatable_type: translatable_resource_type, friendly_id: id_param,
                             collection: resource_collection)
      Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(
        translatable_type:,
        key: 'slug',
        value: friendly_id,
        locale: I18n.available_locales,
        translatable_id: collection.select(:id)
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
          value: id_param,
          translatable_id: resource_collection.select(:id)
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

      return handle_resource_not_found if @resource.nil?

      instance_variable_set("@#{resource_name}", @resource)
      @resource
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    # Overridable hook for when the requested resource is absent from the
    # policy-scoped resource_collection. Defaults to the standard 404.
    # Subclasses may override this to distinguish "genuinely doesn't exist /
    # isn't on this platform" from "exists but is excluded from the scope for
    # some other reason" (e.g. redirecting unauthenticated guests to sign in
    # for a private record, instead of a blanket 404), without changing the
    # default behavior for every other resource type.
    def handle_resource_not_found
      render_not_found
    end

    def translatable_resource_type
      resource_class.name
    end

    def set_metric_viewable
      set_resource_instance unless @resource&.persisted?
      self.metric_viewable = @resource if @resource&.persisted?
    end
  end
end
