# frozen_string_literal: true

module BetterTogether
  # Lookup endpoint behind the shared location picker (views/better_together/locations/_picker). It answers for
  # any locatable form by dispatching to LocatableLocation.available_<type>_for, which applies each type's
  # privacy rules for the signed-in person. Types come only from Placeable.included_in_models, and every
  # response is capped so a broad search cannot dump a table.
  class LocationsController < ApplicationController
    MIXED_RESULTS_PER_TYPE = 5
    SINGLE_TYPE_RESULTS = 25
    MAX_SEARCH_LENGTH = 100

    before_action :authenticate_user!
    after_action :verify_authorized

    # With location_type: bare-id options for that one type. Without: every type at once, as "ClassName:id".
    def available
      authorize Geography::LocatableLocation, :available?

      return render(json: mixed_options) if params[:location_type].blank?

      scope = requested_scope
      return render(json: { error: 'Invalid location type' }, status: :unprocessable_content) unless scope

      render json: scope.limit(SINGLE_TYPE_RESULTS).map { |record| { value: record.id, text: label_for(record) } }
    end

    private

    def requested_scope
      klass = placeable_models.find { |model| model.name == params[:location_type].to_s }
      klass && scope_for(klass)
    end

    def placeable_models
      Geography::Placeable.included_in_models
    end

    def search_term
      params[:search].to_s.first(MAX_SEARCH_LENGTH)
    end

    def scope_for(klass)
      method_name = "available_#{klass.name.demodulize.underscore.pluralize}_for"
      return unless Geography::LocatableLocation.respond_to?(method_name)

      Geography::LocatableLocation.public_send(method_name, helpers.current_person, search: search_term)
    end

    def mixed_options
      placeable_models.flat_map do |klass|
        scope = scope_for(klass)
        next [] unless scope

        scope.limit(MIXED_RESULTS_PER_TYPE).map do |record|
          { value: "#{klass.name}:#{record.id}", text: "#{label_for(record)} (#{klass.model_name.human})" }
        end
      end
    end

    def label_for(record)
      record.respond_to?(:to_formatted_s) ? record.to_formatted_s : record.to_s
    end
  end
end
