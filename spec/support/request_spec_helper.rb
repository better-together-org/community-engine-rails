# frozen_string_literal: true

module RequestSpecHelper
  def json
    JSON.parse(response.body)
  end

  def login(email, password)
    post better_together.user_session_path(locale: I18n.locale || I18n.default_locale), params: {
      user: { email: email, password: password }
    }
  end

  def configure_host_platform
    host_platform = create(:better_together_platform, :host, privacy: 'public')
    wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
    wizard.mark_completed
    create(:user, :confirmed, :platform_manager,
           email: 'manager@example.test',
           password: 'password12345')
    host_platform
  end
end
