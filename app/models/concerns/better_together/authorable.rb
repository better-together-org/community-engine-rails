# frozen_string_literal: true

module BetterTogether
  # Transitional contributable concern backed by BetterTogether::Authorship records.
  module Authorable # rubocop:todo Metrics/ModuleLength
    extend ActiveSupport::Concern

    CONTRIBUTION_ROLE_CONFIG = {
      author: BetterTogether::Authorship::AUTHOR_ROLE,
      editor: BetterTogether::Authorship::EDITOR_ROLE,
      reviewer: BetterTogether::Authorship::REVIEWER_ROLE,
      translator: BetterTogether::Authorship::TRANSLATOR_ROLE,
      idea_source: BetterTogether::Authorship::IDEA_SOURCE_ROLE,
      moderator: BetterTogether::Authorship::MODERATOR_ROLE
    }.freeze

    CONTRIBUTION_ROLE_LABELS = {
      'author' => 'Authors',
      'editor' => 'Editors',
      'reviewer' => 'Reviewers',
      'translator' => 'Translators',
      'idea_source' => 'Idea Sources',
      'moderator' => 'Moderators',
      'exchange_initiator' => 'Exchange Initiators',
      'exchange_participant' => 'Exchange Participants'
    }.freeze

    included do # rubocop:todo Metrics/BlockLength
      has_many :contributions,
               -> { positioned },
               as: :authorable,
               class_name: 'BetterTogether::Authorship'
      has_many :authorships,
               -> { positioned },
               as: :authorable,
               class_name: 'BetterTogether::Authorship'
      has_many :authors,
               lambda {
                 where(better_together_authorships: { author_type: 'BetterTogether::Person', role: BetterTogether::Authorship::AUTHOR_ROLE })
               },
               through: :contributions,
               source: :author,
               source_type: 'BetterTogether::Person'
      has_many :robot_authors,
               lambda {
                 where(better_together_authorships: { author_type: 'BetterTogether::Robot', role: BetterTogether::Authorship::AUTHOR_ROLE })
               },
               through: :contributions,
               source: :author,
               source_type: 'BetterTogether::Robot'
      has_many :contributors,
               through: :contributions,
               source: :author

      accepts_nested_attributes_for :contributions, allow_destroy: true

      CONTRIBUTION_ROLE_CONFIG.each do |association_name, role_value|
        plural_name = association_name.to_s.pluralize
        contribution_assoc = :"#{association_name}_contributions"
        robot_assoc = :"robot_#{plural_name}"

        has_many contribution_assoc,
                 -> { where(better_together_authorships: { role: role_value }) },
                 as: :authorable,
                 class_name: 'BetterTogether::Authorship'

        next if association_name == :author

        has_many plural_name.to_sym,
                 -> { where(better_together_authorships: { author_type: 'BetterTogether::Person', role: role_value }) },
                 through: contribution_assoc,
                 source: :author,
                 source_type: 'BetterTogether::Person'
        has_many robot_assoc,
                 -> { where(better_together_authorships: { author_type: 'BetterTogether::Robot', role: role_value }) },
                 through: contribution_assoc,
                 source: :author,
                 source_type: 'BetterTogether::Robot'
      end
    end

    class_methods do
      def permitted_attributes(id: false, destroy: false, exclude_extra: false)
        super + [
          {
            contributions_attributes: BetterTogether::Authorship.permitted_attributes(id:, destroy:)
          }
        ]
      end

      def extra_permitted_attributes
        super + [
          *CONTRIBUTION_ROLE_CONFIG.keys.flat_map do |role_name|
            [
              { "#{role_name}_ids": [] },
              { "robot_#{role_name}_ids": [] }
            ]
          end
        ]
      end
    end

    def governed_authors
      contributors_for(BetterTogether::Authorship::AUTHOR_ROLE)
    end

    def governed_contributors
      contributions.includes(:author).sort_by(&:position).map(&:author).compact
    end

    def editable_contributors
      contributors_for(BetterTogether::Authorship::AUTHOR_ROLE) +
        contributors_for(BetterTogether::Authorship::EDITOR_ROLE)
    end

    def contribution_records_for(role)
      contributions.for_role(role).includes(:author).sort_by(&:position)
    end

    def contributors_for(role)
      contribution_records_for(role).map(&:author).compact
    end

    def contribution_roles_with_contributors
      contribution_records = if association(:contributions).loaded?
                               contributions.to_a
                             else
                               contributions.includes(:author).to_a
                             end

      contribution_records
        .group_by(&:role)
        .transform_values { |role_contributions| role_contributions.map(&:author).compact.uniq }
        .reject { |_role, actors| actors.empty? }
    end

    def github_backed_contributions
      contributions.select do |contribution|
        Array(contribution.details&.fetch('github_sources', nil)).any?
      end
    end

    def github_backed_contribution_count
      github_backed_contributions.size
    end

    def github_backed_source_count
      github_backed_contributions.sum do |contribution|
        Array(contribution.details&.fetch('github_sources', nil)).size
      end
    end

    def github_contributor_handles
      github_backed_contributions.filter_map do |contribution|
        contribution.details&.fetch('github_handle', nil)
      end.uniq.sort
    end

    def contribution_role_label(role)
      CONTRIBUTION_ROLE_LABELS.fetch(role.to_s, role.to_s.humanize)
    end

    def contribution_records_for_form
      contribution_records = association(:contributions).loaded? ? contributions.to_a : contributions.includes(:author).to_a
      contribution_records.sort_by { |contribution| [contribution.position || Float::INFINITY, contribution.id.to_s] }
    end

    def add_governed_contributor(actor, role: BetterTogether::Authorship::AUTHOR_ROLE,
                                 contribution_type: BetterTogether::Authorship::CONTENT_CONTRIBUTION)
      return unless actor

      contributions.find_or_create_by!(
        author: actor,
        role: role.to_s,
        contribution_type: contribution_type.to_s
      )
    end

    def add_creator_as_author
      return unless respond_to?(:creator_id) && creator_id.present?
      return if contributions.exists?

      add_governed_contributor(
        creator,
        role: BetterTogether::Authorship::AUTHOR_ROLE,
        contribution_type: BetterTogether::Authorship::CONTENT_CONTRIBUTION
      )
    end
  end
end
