# frozen_string_literal: true

module BetterTogether
  # Persists view-type preferences in the session
  class ViewPreferencesController < ApplicationController
    VIEW_TYPES = %w[card table list calendar].freeze

    before_action :authenticate_user!

    def update
      key = view_preference_key
      view_type = view_preference_type
      allowed = allowed_view_types

      return render_invalid_view_type unless valid_view_preference?(key, view_type, allowed)

      store_view_preference(key, view_type)
      set_view_preference_flash
      respond_with_view_preference
    end

    private

    def view_preference_key
      params[:key].to_s
    end

    def view_preference_type
      params[:view_type].to_s
    end

    def allowed_view_types
      Array(params[:allowed]).map(&:to_s) & VIEW_TYPES
    end

    def valid_view_preference?(key, view_type, allowed)
      key.present? && allowed.include?(view_type)
    end

    def render_invalid_view_type
      render json: { error: 'invalid_view_type' }, status: :unprocessable_content
    end

    def store_view_preference(key, view_type)
      preferences = session[:view_preferences] || {}
      preferences[key] = view_type
      session[:view_preferences] = preferences
    end

    def set_view_preference_flash
      flash[:notice] = I18n.t('better_together.view_switcher.flash.updated')
    end

    def respond_with_view_preference
      respond_to do |format|
        format.json { head :ok }
        format.turbo_stream { redirect_back fallback_location: main_app.root_path }
        format.html { redirect_back fallback_location: main_app.root_path }
      end
    end
  end
end
