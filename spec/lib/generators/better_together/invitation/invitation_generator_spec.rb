# frozen_string_literal: true

require 'generator_spec'
require 'rails_helper'
require_relative '../../../../../lib/generators/better_together/invitation/invitation_generator'

RSpec.describe BetterTogether::Generators::InvitationGenerator, type: :generator do
  destination File.expand_path('../../../../../../tmp', __dir__)

  after(:all) do
    FileUtils.rm_rf(File.expand_path('../../../../../../tmp', __dir__))
  end

  describe 'basic file generation' do
    arguments %w[workshop --skip-migration]

    before(:all) do
      prepare_destination
      run_generator
    end

    it 'creates the invitation model file' do
      assert_file 'app/models/better_together/project_invitation.rb'
    end

    it 'creates the invitation mailer file' do
      assert_file 'app/mailers/better_together/project_invitations_mailer.rb'
    end

    it 'creates the invitation policy file' do
      assert_file 'app/policies/better_together/project_invitation_policy.rb'
    end

    it 'creates the invitation notifier file' do
      assert_file 'app/notifiers/better_together/project_invitation_notifier.rb'
    end

    it 'creates the invitation factory file' do
      assert_file 'spec/factories/better_together/project_invitations.rb'
    end

    it 'creates the model spec file' do
      assert_file 'spec/models/better_together/project_invitation_spec.rb'
    end

    it 'creates the mailer spec file' do
      assert_file 'spec/mailers/better_together/project_invitations_mailer_spec.rb'
    end

    it 'creates the policy spec file' do
      assert_file 'spec/policies/better_together/project_invitation_policy_spec.rb'
    end

    it 'creates view files' do
      assert_file 'app/views/better_together/project_invitations/index.html.erb'
      assert_file 'app/views/better_together/project_invitations/new.html.erb'
      assert_file 'app/views/better_together/project_invitations/_invitations_table.html.erb'
      assert_file 'app/views/better_together/project_invitations/create.turbo_stream.erb'
      assert_file 'app/views/better_together/project_invitations/resend.turbo_stream.erb'
    end

    it 'generates model with correct class structure' do
      assert_file 'app/models/better_together/project_invitation.rb' do |content|
        expect(content).to include('module BetterTogether')
        expect(content).to include('class ProjectInvitation < Invitation')
        expect(content).to include('def project')
        expect(content).to include('def after_accept!')
        expect(content).to include('def url_for_review')
      end
    end

    it 'generates mailer with correct class structure' do
      assert_file 'app/mailers/better_together/project_invitations_mailer.rb' do |content|
        expect(content).to include('module BetterTogether')
        expect(content).to include('class ProjectInvitationsMailer < InvitationMailerBase')
        expect(content).to include('def invite')
        expect(content).to include('@invitation = params[:invitation]')
        expect(content).to include('@project = @invitation.project')
      end
    end

    it 'generates factory with correct structure' do
      assert_file 'spec/factories/better_together/project_invitations.rb' do |content|
        expect(content).to include('FactoryBot.define')
        expect(content).to include('factory :better_together_project_invitation')
        expect(content).to include('BetterTogether::ProjectInvitation')
        expect(content).to include('trait :with_invitee')
      end
    end
  end

  describe 'with custom invitable model option' do
    arguments %w[team --invitable-model=Organization --skip-migration --skip-views]

    before(:all) do
      prepare_destination
      run_generator
    end

    it 'creates files with custom naming' do
      assert_file 'app/models/better_together/team_invitation.rb'
      assert_file 'app/mailers/better_together/team_invitations_mailer.rb'
      assert_file 'app/policies/better_together/team_invitation_policy.rb'
    end
  end

  describe 'with skip options' do
    arguments %w[project --skip-views --skip-migration]

    before(:all) do
      prepare_destination
      run_generator
    end

    it 'skips view generation when requested' do
      assert_no_directory 'app/views/better_together/project_invitations'
    end

    it 'still creates other files' do
      assert_file 'app/models/better_together/project_invitation.rb'
      assert_file 'app/mailers/better_together/project_invitations_mailer.rb'
      assert_file 'app/policies/better_together/project_invitation_policy.rb'
    end
  end

  describe 'migration generation' do
    arguments %w[project]

    before(:all) do
      prepare_destination
      run_generator
    end

    it 'creates migration file when not skipped' do
      assert_migration 'create_better_together_project_invitations'
    end
  end
end
