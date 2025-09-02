# frozen_string_literal: true

module BetterTogether
  # Convenience configurator for the engine
  class Configuration
    attr_reader :base_url,
                :new_user_password_path,
                :user_class,
                :user_confirmation_path

    delegate :base_url=, to: :BetterTogether

    delegate :new_user_password_path=, to: :BetterTogether

    delegate :user_class=, to: :BetterTogether

    delegate :user_confirmation_path=, to: :BetterTogether
  end
end
