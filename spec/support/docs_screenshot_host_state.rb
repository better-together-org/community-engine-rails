# frozen_string_literal: true

# Docs screenshot specs commit data from the Capybara server thread and several of them change the host
# platform's privacy or access settings. Platforms and communities are in ESSENTIAL_TABLES, so the :deletion
# cleanup keeps those changes, and a later example then fails the privacy ceiling when it creates a public
# record. Put the host platform and its community privacy back to public; `configure_host_platform` resets the
# access settings itself on the next example.
RSpec.configure do |config|
  config.after(:each, :docs_screenshot) do
    host_platform = BetterTogether::Platform.find_by(host: true)
    next unless host_platform

    # rubocop:disable Rails/SkipsModelValidations
    host_platform.update_columns(privacy: 'public')
    BetterTogether::Community.where(id: [host_platform.community_id, host_platform.primary_community&.id].compact)
                             .update_all(privacy: 'public')
    # rubocop:enable Rails/SkipsModelValidations
  end
end
