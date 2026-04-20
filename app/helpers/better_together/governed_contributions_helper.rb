# frozen_string_literal: true

module BetterTogether
  # Shared helper for the nested governed contribution assignment UI.
  module GovernedContributionsHelper
    PERSON_AUTHOR_TYPE = 'BetterTogether::Person'
    ROBOT_AUTHOR_TYPE = 'BetterTogether::Robot'

    def governed_contributions_fieldset(form:, record:)
      render 'better_together/shared/governed_contributions_fields',
             form:,
             record:,
             contribution_records: record.contribution_records_for_form,
             new_contribution: BetterTogether::Authorship.new(
               authorable: record,
               author_type: PERSON_AUTHOR_TYPE,
               role: BetterTogether::Authorship::AUTHOR_ROLE,
               contribution_type: BetterTogether::Authorship::CONTENT_CONTRIBUTION
             ),
             person_options: governed_contribution_person_options,
             robot_options: governed_contribution_robot_options(record),
             role_options: governed_contribution_role_options(record)
    end

    def governed_contribution_options_json(options)
      options.map { |label, value| { text: label, value: value.to_s } }.to_json
    end

    def governed_contribution_role_options(record)
      configured_roles = BetterTogether::Authorable::CONTRIBUTION_ROLE_CONFIG.values
      existing_roles = record.contribution_records_for_form.map(&:role)

      (configured_roles + existing_roles).uniq.map do |role|
        [record.contribution_role_label(role), role]
      end
    end

    def governed_contribution_person_options
      BetterTogether::Person.i18n.order(:name).map { |person| [person.select_option_title, person.id] }
    end

    def governed_contribution_robot_options(record)
      BetterTogether::Robot.available_for_platform(record.platform || Current.platform)
                           .map { |robot| [robot.select_option_title, robot.id] }
    end
  end
end
