# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/upload', aliases: %i[better_together_upload upload] do
    type { 'BetterTogether::Upload' }
    association :platform, factory: :better_together_platform
  end
end
