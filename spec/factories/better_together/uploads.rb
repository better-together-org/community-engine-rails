# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/upload', aliases: %i[better_together_upload upload] do
    type { 'BetterTogether::Upload' }
    # Default to the host platform (already 'public' per the suite seed) so
    # uploads are visible to API/policy scopes that filter by Current.platform.
    # Falls back to a fresh :public platform — the base platform factory
    # defaults to 'private', which would make an overridden 'public'/
    # 'community' upload privacy exceed its platform's privacy ceiling
    # (see PrivacyCeilingValidatable).
    platform do
      Current.platform || BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :public)
    end
  end
end
