# frozen_string_literal: true

module BetterTogether
  # Handles self-service account export creation and download.
  class PersonDataExportsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_person_data_export, only: :show

    def create
      current_user.person.person_data_exports.create!(requested_at: Time.current, format: 'json')

      redirect_to settings_my_data_path(locale: I18n.locale),
                  notice: t('better_together.settings.index.my_data.export_requested'),
                  status: :see_other
    end

    def show
      unless @person_data_export.completed? && @person_data_export.export_file.attached?
        return redirect_to settings_my_data_path(locale: I18n.locale),
                           alert: t('better_together.settings.index.my_data.export_not_ready'),
                           status: :see_other
      end

      send_data @person_data_export.export_file.download,
                filename: @person_data_export.export_file.filename.to_s,
                type: @person_data_export.export_file.content_type,
                disposition: 'attachment'
    end

    private

    def set_person_data_export
      @person_data_export = current_user.person.person_data_exports.find(params[:id])
    end
  end
end
