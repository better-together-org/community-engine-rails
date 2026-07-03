# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/upload', aliases: %i[better_together_upload upload] do
    type { 'BetterTogether::Upload' }
    # :public — the base platform factory defaults to 'private', which would
    # make an overridden 'public'/'community' upload privacy exceed its
    # platform's privacy ceiling (see PrivacyCeilingValidatable).
    association :platform, factory: %i[better_together_platform public]
  end
end
