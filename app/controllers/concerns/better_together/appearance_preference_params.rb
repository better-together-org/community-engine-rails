# frozen_string_literal: true

module BetterTogether
  # Strong params for a person's own appearance preferences (theme and colour mode).
  # Only the signed-in person's own record is ever touched, the theme is dropped when the platform
  # turns personal themes off (the colour mode is an accessibility need and always accepted), and
  # there is no free-form CSS: values are checked against the theme registry by Person validations.
  module AppearancePreferenceParams
    extend ActiveSupport::Concern

    private

    def appearance_params(person)
      return {} unless person.present? && person == current_user&.person

      permitted = params.fetch(:person, {}).slice(:theme, :color_mode).permit(:theme, :color_mode)
      permitted = permitted.except(:theme) unless helpers.host_platform.allow_user_themes?
      permitted
    end
  end
end
