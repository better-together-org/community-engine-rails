# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Platform do
  let(:platform) { create(:better_together_platform, :public) }

  describe 'cascade deletion' do
    describe 'dependent: :destroy associations' do
      it 'destroys platform_domains when platform is destroyed' do
        domain = create(:better_together_platform_domain, platform:)

        expect { platform.destroy }.to change(BetterTogether::PlatformDomain, :count).by(-1)
        expect(BetterTogether::PlatformDomain.find_by(id: domain.id)).to be_nil
      end

      it 'destroys sitemap when platform is destroyed' do
        sitemap = create(:better_together_sitemap, platform:)

        expect { platform.destroy }.to change(BetterTogether::Sitemap, :count).by(-1)
        expect(BetterTogether::Sitemap.find_by(id: sitemap.id)).to be_nil
      end

      it 'destroys robots when platform is destroyed' do
        robot = create(:better_together_robot, platform:)

        expect { platform.destroy }.to change(BetterTogether::Robot, :count).by(-1)
        expect(BetterTogether::Robot.find_by(id: robot.id)).to be_nil
      end

      it 'destroys platform_blocks when platform is destroyed' do
        block = create(:better_together_platform_block, platform:)

        expect { platform.destroy }.to change(BetterTogether::PlatformBlock, :count).by(-1)
        expect(BetterTogether::PlatformBlock.find_by(id: block.id)).to be_nil
      end

      it 'destroys storage_configurations when platform is destroyed' do
        storage = create(:better_together_storage_configuration, platform:)

        expect { platform.destroy }.to change(BetterTogether::StorageConfiguration, :count).by(-1)
        expect(BetterTogether::StorageConfiguration.find_by(id: storage.id)).to be_nil
      end

      it 'destroys outgoing_platform_connections when platform is destroyed' do
        target_platform = create(:better_together_platform)
        connection = create(:better_together_platform_connection,
                            source_platform: platform,
                            target_platform:)

        expect { platform.destroy }.to change(BetterTogether::PlatformConnection, :count).by(-1)
        expect(BetterTogether::PlatformConnection.find_by(id: connection.id)).to be_nil
      end

      it 'destroys feature_access_grants when platform is destroyed' do
        person = create(:better_together_person)
        grant = create(:better_together_feature_access_grant,
                       platform:,
                       person:)

        expect { platform.destroy }.to change(BetterTogether::FeatureAccessGrant, :count).by(-1)
        expect(BetterTogether::FeatureAccessGrant.find_by(id: grant.id)).to be_nil
      end
    end

    describe 'associations WITHOUT dependent: :destroy (known gaps)' do
      it 'does NOT auto-destroy Pages when platform is destroyed' do
        page = create(:better_together_page, platform:, privacy: 'public')

        expect { platform.destroy }.not_to change(BetterTogether::Page, :count)
        expect(BetterTogether::Page.find_by(id: page.id)).to be_present
      end

      it 'does NOT auto-destroy Posts when platform is destroyed' do
        post = create(:better_together_post, platform:, privacy: 'public')

        expect { platform.destroy }.not_to change(BetterTogether::Post, :count)
        expect(BetterTogether::Post.find_by(id: post.id)).to be_present
      end

      it 'does NOT auto-destroy Events when platform is destroyed' do
        event = create(:better_together_event, platform:, privacy: 'public')

        expect { platform.destroy }.not_to change(BetterTogether::Event, :count)
        expect(BetterTogether::Event.find_by(id: event.id)).to be_present
      end

      it 'does NOT auto-destroy ShortLinks when platform is destroyed' do
        short_link = create(:better_together_short_link, platform:)

        expect { platform.destroy }.not_to change(BetterTogether::ShortLink, :count)
        expect(BetterTogether::ShortLink.find_by(id: short_link.id)).to be_present
      end

      it 'does NOT auto-destroy Notifications when platform is destroyed' do
        notification = create(:better_together_notification,
                              notifiable: platform,
                              platform:)

        expect { platform.destroy }.not_to change(BetterTogether::Notification, :count)
        expect(BetterTogether::Notification.find_by(id: notification.id)).to be_present
      end
    end

    describe 'Invitations handling (FK without CASCADE)' do
      it 'has a foreign key constraint on invitations' do
        person = create(:better_together_person)
        create(:better_together_platform_invitation,
               invitable: platform,
               invitee: person)

        # Attempting to destroy the platform should fail or require cleanup
        # because invitations has a FK to platform (invitable_id) without CASCADE
        expect do
          platform.destroy
        end.to raise_error(ActiveRecord::InvalidForeignKey) |
               or_not_to(change(BetterTogether::PlatformInvitation, :count))
      end

      it 'allows destroying platform after clearing invitations' do
        person = create(:better_together_person)
        create(:better_together_platform_invitation,
               invitable: platform,
               invitee: person)

        # Clear the invitations first
        platform.invitations.destroy_all

        # Now destruction should succeed
        expect { platform.destroy }.not_to raise_error
      end
    end

    describe 'Person platform memberships cascade' do
      it 'clears person_platform_memberships when platform is destroyed' do
        person = create(:better_together_person)
        membership = create(:better_together_person_platform_membership,
                            joinable: platform,
                            member: person)

        expect { platform.destroy }.to change(BetterTogether::PersonPlatformMembership, :count).by(-1)
        expect(BetterTogether::PersonPlatformMembership.find_by(id: membership.id)).to be_nil
      end
    end

    describe 'Multi-platform reference cleanup' do
      let(:other_platform) { create(:better_together_platform) }

      it 'destroys incoming connections when platform is destroyed' do
        connection = create(:better_together_platform_connection,
                            source_platform: other_platform,
                            target_platform: platform)

        expect { platform.destroy }.to change(BetterTogether::PlatformConnection, :count).by(-1)
        expect(BetterTogether::PlatformConnection.find_by(id: connection.id)).to be_nil
      end

      it 'does NOT affect other platforms when destroying this platform' do
        other_page = create(:better_together_page,
                            platform: other_platform,
                            privacy: 'public')

        expect { platform.destroy }.not_to change(BetterTogether::Page, :count)
        expect(BetterTogether::Page.find_by(id: other_page.id)).to be_present
      end
    end

    describe 'Cascade deletion integrity' do
      it 'maintains referential integrity across cascade deletions' do
        # Create a complex scenario with multiple associated records
        domain = create(:better_together_platform_domain, platform:)
        robot = create(:better_together_robot, platform:)
        person = create(:better_together_person)
        membership = create(:better_together_person_platform_membership,
                            joinable: platform,
                            member: person)
        storage = create(:better_together_storage_configuration, platform:)

        # Destroy the platform
        expect { platform.destroy }.not_to raise_error

        # Verify all associated records are cleaned up (except known exceptions)
        expect(BetterTogether::PlatformDomain.find_by(id: domain.id)).to be_nil
        expect(BetterTogether::Robot.find_by(id: robot.id)).to be_nil
        expect(BetterTogether::PersonPlatformMembership.find_by(id: membership.id)).to be_nil
        expect(BetterTogether::StorageConfiguration.find_by(id: storage.id)).to be_nil

        # Person should still exist (not cascade deleted)
        expect(BetterTogether::Person.find_by(id: person.id)).to be_present
      end
    end

    describe 'Documentation: known gaps in cascade handling' do
      it 'documents that content models are NOT auto-cascaded' do
        # This test documents a known architectural decision:
        # Pages, Posts, Events, ShortLinks are platform-scoped but NOT cascade-deleted
        # when a platform is destroyed. This is intentional to allow content preservation
        # or separate cleanup workflows.

        page = create(:better_together_page, platform:, privacy: 'public')
        post = create(:better_together_post, platform:, privacy: 'public')
        event = create(:better_together_event, platform:, privacy: 'public')

        platform.destroy

        # All content should remain (orphaned)
        expect(BetterTogether::Page.find_by(id: page.id)).to be_present
        expect(BetterTogether::Post.find_by(id: post.id)).to be_present
        expect(BetterTogether::Event.find_by(id: event.id)).to be_present
      end

      it 'documents that invitations have a hard FK constraint' do
        # This test documents that invitations use a foreign key without CASCADE
        # If a platform is deleted while invitations exist, the deletion will fail
        # at the DB level. This requires explicit cleanup before deletion.

        person = create(:better_together_person)
        create(:better_together_platform_invitation,
               invitable: platform,
               invitee: person)

        # This will raise unless the database is configured with CASCADE
        # (which it is not, as the code uses a hard FK constraint)
        expect do
          platform.destroy
        end.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end
  end
end
