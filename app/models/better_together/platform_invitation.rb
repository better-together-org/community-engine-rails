
module BetterTogether
  class PlatformInvitation < ApplicationRecord
    has_secure_token

    belongs_to :invitee,
               class_name: '::BetterTogether::Person',
               foreign_key: 'invitee_id'
    belongs_to :inviter,
               class_name: '::BetterTogether::Person',
               foreign_key: 'inviter_id'
    belongs_to :invitable,
               class_name: '::BetterTogether::Platform',
               foreign_key: 'invitable_id'
    belongs_to :platform_role,
               class_name: '::BetterTogether::Role',
               foreign_key: 'platform_role_id'
    belongs_to :community_role,
               class_name: '::BetterTogether::Role',
               foreign_key: 'community_role_id'

    validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
  end
end