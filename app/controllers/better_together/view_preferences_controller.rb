# frozen_string_literal: true

module BetterTogether
  # Persists view-type preferences in the session
  class ViewPreferencesController < ApplicationController
    VIEW_TYPES = %w[card table list calendar].freeze

    before_action :authenticate_user!

    def update
      key = params[:key].to_s
      view_type = params[:view_type].to_s
      allowed = Array(params[:allowed]).map(&:to_s) & VIEW_TYPES

      unless key.present? && allowed.include?(view_type)
        return render json: { error: 'invalid_view_type' }, status: :unprocessable_content
      end

      preferences = session[:view_preferences] || {}
      preferences[key] = view_type
      session[:view_preferences] = preferences
      flash[:notice] = I18n.t('better_together.view_switcher.flash.updated')

      respond_to do |format|
        format.json { head :ok }
        format.turbo_stream { redirect_back fallback_location: main_app.root_path }
        format.html { redirect_back fallback_location: main_app.root_path }
      end
    end
  end
end
