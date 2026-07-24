# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CommentMailer do
  def create_tenant(community:, domain:)
    platform = create(:better_together_platform, community:, host_url: "https://#{domain}")
    platform.platform_domains.find_or_create_by!(hostname: domain) do |platform_domain|
      platform_domain.primary = true
      platform_domain.active = true
    end
    platform
  end

  describe '#added' do
    context 'when the platform has an inbound-mail domain and inbound mail is enabled' do
      it 'sets a reply+<token>@ Reply-To header and issues a redeemable token' do
        community = create(:better_together_community, name: 'Comment Mailer Tenant')
        platform = create_tenant(community:, domain: 'tenant-comment-mailer.example.test')
        recipient = create(:better_together_person)
        post = create(:better_together_post)
        comment = create(:comment, commentable: post)

        Current.set(platform:) do
          mail = described_class.with(comment:, recipient:).added

          expect(mail['Reply-To']&.value).to match(/\Areply\+[A-Za-z0-9_-]+@tenant-comment-mailer\.example\.test\z/)

          token_value = mail['Reply-To'].value[/\Areply\+([^@]+)@/, 1]
          token = BetterTogether::InboundEmailReplyToken.find_by(token: token_value)
          expect(token).to be_present
          expect(token.recipient).to eq(recipient)
          expect(token.repliable).to eq(post)
          expect(token.notification_type).to eq('comment_added')
          expect(token).to be_usable
        end
      end
    end

    context 'when the platform has disabled inbound mail' do
      it 'does not set a Reply-To header or issue a token' do
        community = create(:better_together_community, name: 'Comment Mailer Disabled Tenant')
        platform = create_tenant(community:, domain: 'tenant-comment-mailer-disabled.example.test')
        platform.update!(allow_inbound_mail: false)
        recipient = create(:better_together_person)
        post = create(:better_together_post)
        comment = create(:comment, commentable: post)

        Current.set(platform:) do
          expect do
            mail = described_class.with(comment:, recipient:).added
            expect(mail['Reply-To']).to be_nil
          end.not_to change(BetterTogether::InboundEmailReplyToken, :count)
        end
      end
    end
  end
end
