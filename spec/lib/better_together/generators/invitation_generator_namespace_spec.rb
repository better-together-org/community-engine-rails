# frozen_string_literal: true

require 'spec_helper'
require 'generator_spec'
require 'generators/better_together/invitation/invitation_generator'
require 'tmpdir'

RSpec.describe BetterTogether::Generators::InvitationGenerator, type: :generator do
  around do |example|
    tmp_dir = Dir.mktmpdir('bt-invitation-generator-namespace-')
    self.class.destination(tmp_dir)
    prepare_destination
    example.run
  ensure
    FileUtils.rm_rf(tmp_dir) if tmp_dir
  end

  describe 'context-aware defaults' do
    context 'when running in engine context' do
      before do
        # Create better_together directory to simulate engine context
        FileUtils.mkdir_p(File.join(destination_root, 'app', 'models', 'better_together'))
        run_generator(%w[project])
      end

      it 'defaults to BetterTogether namespace' do
        assert_file 'app/models/better_together/project_invitation.rb' do |content|
          expect(content).to include('module BetterTogether')
          expect(content).to include('class ProjectInvitation')
        end
      end
    end

    context 'when running in host app context' do
      before do
        # Don't create better_together directory - simulates host app
        run_generator(%w[project])
      end

      it 'defaults to no namespace' do
        assert_file 'app/models/project_invitation.rb' do |content|
          expect(content).to include('class ProjectInvitation')
          expect(content).not_to include('module BetterTogether')
        end
      end
    end
  end

  describe 'with custom namespace' do
    before do
      run_generator(%w[project --namespace=MyApp])
    end

    it 'creates model in custom namespace directory' do
      assert_file 'app/models/my_app/project_invitation.rb' do |content|
        expect(content).to include('module MyApp')
        expect(content).to include('class ProjectInvitation')
      end
    end

    it 'creates mailer in custom namespace directory' do
      assert_file 'app/mailers/my_app/project_invitations_mailer.rb' do |content|
        expect(content).to include('module MyApp')
        expect(content).to include('class ProjectInvitationsMailer')
      end
    end

    it 'creates policy in custom namespace directory' do
      assert_file 'app/policies/my_app/project_invitation_policy.rb' do |content|
        expect(content).to include('module MyApp')
        expect(content).to include('class ProjectInvitationPolicy')
      end
    end

    it 'creates factory in custom namespace directory' do
      assert_file 'spec/factories/my_app/project_invitations.rb' do |content|
        expect(content).to include('factory :my_app_project_invitation')
        expect(content).to include('MyApp::ProjectInvitation')
      end
    end
  end

  describe 'with custom namespace and migration' do
    before do
      run_generator(%w[project --namespace=MyApp --with-migration])
    end

    it 'generates migration with namespace-prefixed table name' do
      migration_file = Dir.glob("#{destination_root}/db/migrate/*_create_my_app_project_invitations.rb").first
      expect(migration_file).not_to be_nil

      assert_migration 'db/migrate/create_my_app_project_invitations.rb' do |content|
        expect(content).to include('class CreateMyAppProjectInvitations')
        expect(content).to include('create_bt_table :project_invitations')
        expect(content).to include("t.bt_locale('my_app_project_invitations')")
      end
    end
  end

  describe 'with empty namespace (no namespace)' do
    before do
      run_generator(['project', '--namespace', ''])
    end

    it 'creates model at root level' do
      assert_file 'app/models/project_invitation.rb' do |content|
        expect(content).to include('class ProjectInvitation')
        expect(content).not_to include('module ')
      end
    end

    it 'creates mailer at root level' do
      assert_file 'app/mailers/project_invitations_mailer.rb' do |content|
        expect(content).to include('class ProjectInvitationsMailer')
        expect(content).not_to include('module ')
      end
    end

    it 'creates policy at root level' do
      assert_file 'app/policies/project_invitation_policy.rb' do |content|
        expect(content).to include('class ProjectInvitationPolicy')
        expect(content).not_to include('module ')
      end
    end

    it 'creates factory at root level' do
      assert_file 'spec/factories/project_invitations.rb' do |content|
        expect(content).to include('factory :project_invitation')
        expect(content).to include('ProjectInvitation')
      end
    end
  end

  describe 'with empty namespace and migration' do
    before do
      run_generator(['project', '--namespace', '', '--with-migration'])
    end

    it 'generates migration with non-prefixed table name' do
      migration_file = Dir.glob("#{destination_root}/db/migrate/*_create_project_invitations.rb").first
      expect(migration_file).not_to be_nil

      assert_migration 'db/migrate/create_project_invitations.rb' do |content|
        expect(content).to include('class CreateProjectInvitations')
        expect(content).to include('create_bt_table :project_invitations')
        expect(content).to include("t.bt_locale('project_invitations')")
      end
    end
  end

  describe 'explicit BetterTogether namespace' do
    before do
      run_generator(%w[project --namespace=BetterTogether])
    end

    it 'uses BetterTogether namespace when explicitly specified' do
      assert_file 'app/models/better_together/project_invitation.rb' do |content|
        expect(content).to include('module BetterTogether')
        expect(content).to include('class ProjectInvitation')
      end
    end
  end
end
