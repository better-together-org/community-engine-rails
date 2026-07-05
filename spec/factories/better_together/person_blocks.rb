# frozen_string_literal: true

# FactoryBot factories for BetterTogether models.
module BetterTogether # :nodoc:
  FactoryBot.define do
    factory :person_block, class: PersonBlock do
      association :blocker, factory: :better_together_person
      association :blocked, factory: :better_together_person

      # Default to the host platform instead of always spinning up a fresh unrelated
      # Platform record — PersonBlock is per-platform, and policy scopes
      # (PersonBlockPolicy::Scope) filter by the current/host platform, so a block
      # built on its own throwaway platform would be invisible to those scopes.
      # Deliberately does NOT fall back to Current.platform here (unlike the model's
      # own PlatformScoped#assign_current_platform_if_available default) — controller
      # specs elsewhere in the suite can leave Current.platform set to a non-host
      # platform between examples, and this factory should stay deterministic
      # regardless of that ambient state.
      before(:create) do |person_block|
        unless person_block.platform_id.present?
          person_block.platform = BetterTogether::Platform.find_by(host: true) ||
                                  create(:better_together_platform)
        end
      end
    end
  end
end
