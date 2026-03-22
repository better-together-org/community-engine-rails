# frozen_string_literal: true

module BetterTogether
  # Persists per-user help banner visibility preferences
  class HelpPreferencesController < ApplicationController
    before_action :authenticate_user!

    def hide
      update_banner(hidden: true)
    end

    def show
      update_banner(hidden: false)
    end

    private

    # rubocop:todo Metrics/MethodLength
    def update_banner(hidden:) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      banner_id = params[:id].to_s.presence || 'help'
      person = helpers.current_person
      prefs = person.preferences || {}
      banners = prefs['help_banners'] || {}
      banners[banner_id] = { 'hidden' => hidden, 'locale' => I18n.locale.to_s, 'updated_at' => Time.current }
      prefs['help_banners'] = banners
      person.update!(preferences: prefs)

      respond_to do |format|
        format.json { head :ok }
        format.turbo_stream { head :ok }
        format.html { redirect_back fallback_location: main_app.root_path }
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
