# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Platform do
  let(:platform) { create(:better_together_platform, :public) }

  describe 'cascade deletion' do
    describe 'dependent: :destroy associations' do
      it 'destroys platform_domains when platform is destroyed' do
        # Platform#sync_primary_platform_domain! (after_commit) already created a
        # primary domain from host_url, so destroying the platform clears both it
        # and the extra domain created below.
        domain = create(:better_together_platform_domain, platform:)

        expect { platform.destroy }.to change(BetterTogether::PlatformDomain, :count).by(-2)
        expect(BetterTogether::PlatformDomain.find_by(id: domain.id)).to be_nil
      end

      it 'destroys sitemap when platform is destroyed' do
        sitemap = create(:better_together_sitemap, platform:)
        # Attaching the sitemap file triggers an internal re-save that the
        # already-loaded `platform.sitemap` association target doesn't see;
        # reload so the cascade delete uses a current lock_version.
        platform.reload

        expect { platform.destroy }.to change(BetterTogether::Sitemap, :count).by(-1)
        expect(BetterTogether::Sitemap.find_by(id: sitemap.id)).to be_nil
      end

      it 'destroys robots when platform is destroyed' do
        robot = create(:better_together_robot, platform:)

        expect { platform.destroy }.to change(BetterTogether::Robot, :count).by(-1)
        expect(BetterTogether::Robot.find_by(id: robot.id)).to be_nil
      end

      it 'destroys platform_blocks when platform is destroyed' do
        block = platform.platform_blocks.create!(block: create(:content_alert_block))

        expect { platform.destroy }.to change(BetterTogether::Content::PlatformBlock, :count).by(-1)
        expect(BetterTogether::Content::PlatformBlock.find_by(id: block.id)).to be_nil
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
      # Pages, Posts, Events, and ShortLinks are platform-scoped via a hard
      # foreign key with no ON DELETE CASCADE and no `dependent:` option, so
      # destroying a platform that still has any of this content fails at the
      # DB level rather than silently orphaning or cascading it. This mirrors
      # the Invitations behavior below and requires explicit cleanup first.
      it 'does NOT auto-destroy Pages when platform is destroyed' do
        page = create(:better_together_page, platform:, privacy: 'public')

        expect { platform.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
        expect(BetterTogether::Page.find_by(id: page.id)).to be_present
      end

      it 'does NOT auto-destroy Posts when platform is destroyed' do
        post = create(:better_together_post, platform:, privacy: 'public')

        expect { platform.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
        expect(BetterTogether::Post.find_by(id: post.id)).to be_present
      end

      it 'does NOT auto-destroy Events when platform is destroyed' do
        event = create(:better_together_event, platform:, privacy: 'public')

        expect { platform.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
        expect(BetterTogether::Event.find_by(id: event.id)).to be_present
      end

      it 'does NOT auto-destroy ShortLinks when platform is destroyed' do
        short_link = create(:better_together_short_link, platform:)

        expect { platform.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
        expect(BetterTogether::ShortLink.find_by(id: short_link.id)).to be_present
      end
    end

    describe 'Invitations handling (FK without CASCADE)' do
      it 'has a foreign key constraint on invitations' do
        person = create(:better_together_person)
        create(:better_together_platform_invitation,
               invitable: platform,
               invitee: person)

        # Platform#invitations (PlatformInvitation) has a hard FK to platform
        # (invitable_id) without CASCADE or `dependent:` — destroying the
        # platform while invitations exist fails at the DB level.
        expect { platform.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
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
      it 'does NOT auto-destroy person_platform_memberships when platform is destroyed' do
        person = create(:better_together_person)
        membership = create(:better_together_person_platform_membership,
                            joinable: platform,
                            member: person)

        # Platform's `joinable` macro does not pass `dependent: :destroy` for
        # person_platform_memberships, so this is a hard FK, not a cascade.
        expect { platform.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
        expect(BetterTogether::PersonPlatformMembership.find_by(id: membership.id)).to be_present
      end
    end

    describe 'Multi-platform reference cleanup' do
      let(:other_platform) { create(:better_together_platform, :public) }

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
        # Create a complex scenario with multiple associated records that
        # ARE configured with dependent: :destroy (memberships and content
        # models are covered separately above since they use hard FKs).
        domain = create(:better_together_platform_domain, platform:)
        robot = create(:better_together_robot, platform:)
        storage = create(:better_together_storage_configuration, platform:)

        # Destroy the platform
        expect { platform.destroy }.not_to raise_error

        # Verify all associated records are cleaned up
        expect(BetterTogether::PlatformDomain.find_by(id: domain.id)).to be_nil
        expect(BetterTogether::Robot.find_by(id: robot.id)).to be_nil
        expect(BetterTogether::StorageConfiguration.find_by(id: storage.id)).to be_nil
      end
    end

    describe 'Documentation: known gaps in cascade handling' do
      it 'documents that content models are NOT auto-cascaded' do
        # This test documents a known architectural decision:
        # Pages, Posts, Events, ShortLinks are platform-scoped but NOT cascade-deleted
        # when a platform is destroyed — the hard FK blocks destruction outright until
        # the content is explicitly cleaned up or reassigned.

        page = create(:better_together_page, platform:, privacy: 'public')

        expect { platform.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)

        # Content remains untouched because the destroy transaction rolled back.
        expect(BetterTogether::Page.find_by(id: page.id)).to be_present
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
