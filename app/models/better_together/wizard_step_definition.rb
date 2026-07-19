# frozen_string_literal: true

# app/models/better_together/wizard_step_definition.rb
module BetterTogether
  # Defines steps for wizards
  class WizardStepDefinition < PlatformRecord
    include Identifier
    include Protected

    belongs_to :wizard

    has_many :wizard_steps,
             class_name: '::BetterTogether::WizardStep'

    # slug_uniqueness: false — matches Wizard's own identical fix (see that
    # model's comment). Without this, FriendlySlug#slugged's default
    # `slug_uniqueness: true` adds a SECOND, always-GLOBAL
    # `validates :slug, uniqueness: true` on top of the Identifier concern's
    # own (correctly platform_id-scoped, but here skipped — see
    # skip_validate_identifier? below) uniqueness check, and on top of this
    # model's own explicit `validates :identifier, uniqueness: { scope:
    # :wizard_id }` a few lines down. Every new_platform_setup provisioning
    # run mints a fresh Wizard + a full set of WizardStepDefinition rows with
    # the SAME identifiers ("welcome", "platform_identity", etc.) by design —
    # without this flag, only the very first platform ever provisioned could
    # succeed; every later run's create! would raise "Slug has already been
    # taken" regardless of platform_id/wizard_id scoping, since the redundant
    # global slug check doesn't scope by anything. See the accompanying
    # migration (20260719160000) for the matching DB-index half of this fix.
    slugged :identifier, dependent: :delete_all, slug_uniqueness: false

    translates :name, type: :string
    translates :description, type: :text

    validates :name, presence: true
    validates :description, presence: true

    validates :identifier,
              presence: true,
              uniqueness: {
                scope: :wizard_id,
                case_sensitive: false
              },
              length: { maximum: 100 }

    validates :step_number,
              numericality: {
                only_integer: true,
                greater_than: 0
              },
              uniqueness: { scope: :wizard_id }
    validates :message, presence: true

    scope :ordered, -> { order(:step_number) }

    # Additional logic and methods as needed

    # ...

    # Method to build a new wizard step for this definition
    def build_wizard_step
      wizard.wizard_steps.build(wizard_step_definition: self, identifier:, step_number:)
    end

    # Method to create a new wizard step for this definition
    def create_wizard_step
      wizard_step = build_wizard_step

      wizard_step.save

      wizard_step
    end

    # Method to return the routing path
    def routing_path
      "#{wizard.identifier.underscore}/#{identifier.underscore}"
    end

    def skip_validate_identifier?
      true
    end

    def template
      self[:template].presence || template_path
    end

    # Method to return the default path to the template
    def template_path
      "better_together/wizard_step_definitions/#{routing_path}"
    end
  end
end
