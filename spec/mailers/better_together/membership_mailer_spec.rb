# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe MembershipMailer do
    let(:role) { create(:better_together_role, :community_role, name: 'Community Coordinator') }
    let(:permissions) do
      create_list(:better_together_resource_permission, 8, resource_type: 'BetterTogether::Community')
    end
    let(:membership) { create(:better_together_person_community_membership, role: role) }

    before do
      role.resource_permissions << permissions
    end

    describe '#created' do
      let(:mail) { described_class.with(membership: membership, recipient: membership.member).created }

      it 'renders the headers' do
        expect(mail.subject).to eq(I18n.t('better_together.membership_mailer.created.subject',
                                          joinable_name: membership.joinable.name,
                                          joinable_type: membership.joinable.model_name.human))
        expect(mail.to).to eq([membership.member.email])
      end

      it 'includes role and permission summary content' do
        first_permission_label = permissions.first.identifier.to_s.tr('_', ' ').humanize

        expect(mail.body.encoded).to include(role.name)
        expect(mail.body.encoded).to include(first_permission_label)
        expect(mail.body.encoded).to include(
          I18n.t('better_together.membership_mailer.created.permissions_summary_more', count: 2)
        )
      end
    end
  end
end
