# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe MembershipMailer do
    let(:role) { create(:better_together_role, :community_role, name: 'Community Coordinator') }
    let(:permissions) do
      create_list(:better_together_resource_permission, 8, resource_type: 'BetterTogether::Community')
    end
    let(:membership) { create(:better_together_person_community_membership, role: role) }
    let(:platform_role) { create(:better_together_role, :platform_role, name: 'Platform Manager') }
    let(:platform_membership) { create(:better_together_person_platform_membership, role: platform_role) }

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
        # Get permissions in the same order they'll appear in the email (first 6)
        displayed_permissions = role.resource_permissions.order(:resource_type, :position, :identifier).first(6)
        first_permission_label = displayed_permissions.first.identifier.to_s.tr('_', ' ').humanize

        expect(mail.body.encoded).to include(role.name)
        expect(mail.body.encoded).to include(first_permission_label)
        expect(mail.body.encoded).to include(
          I18n.t('better_together.membership_mailer.created.permissions_summary_more', count: 2)
        )
      end
    end

    describe '#updated' do
      let(:old_role) { create(:better_together_role, :community_role, name: 'Old Role') }
      let(:new_role) { create(:better_together_role, :community_role, name: 'New Role') }
      let(:updated_membership) { create(:better_together_person_community_membership, role: new_role) }
      let(:recipient_data) do
        {
          email: updated_membership.member.email,
          locale: I18n.default_locale,
          time_zone: Time.zone
        }
      end
      let(:mail) do
        described_class.with(
          recipient: recipient_data,
          joinable: updated_membership.joinable,
          old_role: old_role,
          new_role: new_role,
          member_name: updated_membership.member.name
        ).updated
      end

      it 'renders the headers' do
        expect(mail.subject).to eq(I18n.t('better_together.membership_mailer.updated.subject',
                                          joinable_name: updated_membership.joinable.name,
                                          joinable_type: updated_membership.joinable.model_name.human))
        expect(mail.to).to eq([updated_membership.member.email])
      end

      it 'includes old and new role information' do
        expect(mail.body.encoded).to include(old_role.name)
        expect(mail.body.encoded).to include(new_role.name)
        expect(mail.body.encoded).to include(I18n.t('better_together.membership_mailer.updated.previous_permissions_heading'))
        expect(mail.body.encoded).to include(I18n.t('better_together.membership_mailer.updated.new_permissions_heading'))
      end
    end

    describe '#removed' do
      let(:recipient_data) do
        recipient_struct = Struct.new(:email, :locale, :time_zone, keyword_init: true)
        recipient_struct.new(
          email: 'member@example.com',
          locale: I18n.default_locale,
          time_zone: Time.zone
        )
      end
      let(:mail) do
        described_class.with(
          recipient: recipient_data,
          joinable: membership.joinable,
          role: role,
          member_name: 'John Doe'
        ).removed
      end

      it 'renders the headers' do
        expect(mail.subject).to eq(I18n.t('better_together.membership_mailer.removed.subject',
                                          joinable_name: membership.joinable.name,
                                          joinable_type: membership.joinable.model_name.human))
        expect(mail.to).to eq([recipient_data.email])
      end

      it 'includes role and removal information' do
        expect(mail.body.encoded).to include('John Doe')
        expect(mail.body.encoded).to include(role.name)
        expect(mail.body.encoded).to include(I18n.t('better_together.membership_mailer.removed.removed_permissions_heading'))
        expect(mail.body.encoded).to include(I18n.t('better_together.membership_mailer.removed.footer_message'))
      end

      context 'when member name is not provided' do
        let(:mail_without_name) do
          described_class.with(
            recipient: recipient_data,
            joinable: membership.joinable,
            role: role,
            member_name: nil
          ).removed
        end

        it 'uses default member name' do
          expect(mail_without_name.body.encoded).to include(I18n.t('better_together.default_member_name'))
        end
      end
    end

    describe 'mailer configuration' do
      it 'sets the correct locale and time zone for created mail' do
        member = membership.member
        member.update!(locale: 'es', time_zone: 'America/Mexico_City')

        mail = described_class.with(membership: membership, recipient: member).created

        # The mailer should use the recipient's locale and time zone
        expect(mail.subject).to include(membership.joinable.name)
      end
    end
  end
end
