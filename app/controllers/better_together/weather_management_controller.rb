# frozen_string_literal: true

module BetterTogether
  # Host dashboard Weather tab. Host stewards (manage_platform_settings on the host platform) see the
  # host-wide switch, the sources and their locations, and switch each on or off after a confirm step.
  class WeatherManagementController < ApplicationController
    skip_third_party_tracking
    after_action :verify_authorized

    before_action :set_overview
    before_action :set_source, only: %i[source confirm_source update_source]
    before_action :set_location, only: %i[confirm_location update_location]

    def show
      authorize :weather, :index?, policy_class: WeatherPolicy
      render_tab('overview')
    end

    def source
      authorize @source, :index?
      render_tab('source')
    end

    def confirm_feature
      authorize :weather, :update?, policy_class: WeatherPolicy
      return redirect_env_forced_off if @overview.env_forced_off?

      @target_enabled = requested_enabled?
      render_tab('confirm_feature')
    end

    def update_feature
      authorize :weather, :update?, policy_class: WeatherPolicy
      return redirect_env_forced_off if @overview.env_forced_off?

      toggle(Current.host_platform, notice_key: 'feature', redirect: host_dashboard_weather_path)
    end

    def confirm_source
      authorize @source, :update?
      @target_enabled = requested_enabled?
      render_tab('confirm_source')
    end

    def update_source
      authorize @source, :update?
      toggle(@source, notice_key: 'source', redirect: host_dashboard_weather_path, name: @source.identifier)
    end

    def confirm_location
      authorize @location, :update?
      @target_enabled = requested_enabled?
      render_tab('confirm_location')
    end

    def update_location
      authorize @location, :update?
      toggle(@location, notice_key: 'location', redirect: host_dashboard_weather_source_path(@location.source),
                        name: @location.settlement&.name)
    end

    private

    def set_overview
      @overview = Weather::StewardOverview.new
    end

    def set_source
      @source = Weather::Source.find(params[:id])
    end

    def set_location
      @location = Weather::Location.includes(:source, settlement: :string_translations).find(params[:id])
    end

    def requested_enabled?
      ActiveModel::Type::Boolean.new.cast(params[:enabled]) ? true : false
    end

    def render_tab(tab)
      @weather_tab = tab
      render :show
    end

    def toggle(record, notice_key:, redirect:, name: nil)
      result = Weather::StewardToggle.call(record, enabled: requested_enabled?, actor: helpers.current_person)
      state = result.after ? 'enabled' : 'disabled'
      key = result.changed? ? "#{notice_key}_#{state}" : 'unchanged'
      redirect_to redirect, status: :see_other, notice: t("host_dashboard.weather.flash.#{key}", name:)
    end

    def redirect_env_forced_off
      redirect_to host_dashboard_weather_path, status: :see_other,
                                               alert: t('host_dashboard.weather.flash.env_forced_off')
    end
  end
end
