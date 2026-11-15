# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformFromParent do
  let(:platform) { create(:better_together_platform) }
  let(:other_platform) { create(:better_together_platform) }

  describe 'agreement terms' do
    let(:agreement) { create(:better_together_agreement, platform:) }
    let(:other_agreement) { create(:better_together_agreement, platform: other_platform) }

    it 'takes the platform of the agreement' do
      term = create(:better_together_agreement_term, agreement:, identifier: 'privacy', platform: nil)

      expect(term.platform_id).to eq(platform.id)
    end

    it 'rejects a platform that differs from the agreement' do
      term = build(:better_together_agreement_term, agreement:, platform: other_platform)

      expect(term).not_to be_valid
    end

    it 'allows one identifier under two agreements on two platforms' do
      create(:better_together_agreement_term, agreement:, identifier: 'privacy')

      expect(build(:better_together_agreement_term, agreement: other_agreement, identifier: 'privacy')).to be_valid
    end

    it 'rejects the same identifier twice under one agreement' do
      create(:better_together_agreement_term, agreement:, identifier: 'privacy')

      expect(build(:better_together_agreement_term, agreement:, identifier: 'privacy')).not_to be_valid
    end
  end

  describe 'checklist items' do
    let(:checklist) { create(:better_together_checklist, platform:) }

    it 'takes the platform of the checklist' do
      item = create(:better_together_checklist_item, checklist:, platform: nil)

      expect(item.platform_id).to eq(platform.id)
    end

    it 'rejects a platform that differs from the checklist' do
      expect(build(:better_together_checklist_item, checklist:, platform: other_platform)).not_to be_valid
    end
  end

  describe 'wizard children' do
    let(:wizard) { create(:better_together_wizard, platform:) }

    it 'puts step definitions on the wizard platform' do
      definition = create(:better_together_wizard_step_definition, wizard:, platform: nil)

      expect(definition.platform_id).to eq(platform.id)
    end

    it 'puts steps on the wizard platform' do
      definition = create(:better_together_wizard_step_definition, wizard:)
      step = create(:better_together_wizard_step, wizard:, wizard_step_definition: definition, platform: nil)

      expect(step.platform_id).to eq(platform.id)
    end

    it 'resolves a wizard identifier per platform' do
      mine = create(:better_together_wizard, platform:, identifier: 'setup')
      theirs = create(:better_together_wizard, platform: other_platform, identifier: 'setup')

      expect([BetterTogether::Wizard.for_identifier('setup', platform:),
              BetterTogether::Wizard.for_identifier('setup', platform: other_platform)]).to eq([mine, theirs])
    end

    it 'falls back to the host platform wizard for a tenant platform that has none', :aggregate_failures do
      host = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true)
      host_wizard = create(:better_together_wizard, platform: host, identifier: 'host_probe')

      expect(BetterTogether::Wizard.for_identifier('host_probe', platform: other_platform)).to eq(host_wizard)
    end

    it 'falls back to a platformless wizard, then to any wizard with the identifier', :aggregate_failures do
      only = create(:better_together_wizard, platform: platform, identifier: 'solo')
      expect(BetterTogether::Wizard.for_identifier('solo', platform: other_platform)).to eq(only)

      shared = create(:better_together_wizard, platform: nil, identifier: 'shared')
      expect(BetterTogether::Wizard.for_identifier('shared', platform: other_platform)).to eq(shared)
    end
  end
end
