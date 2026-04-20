# frozen_string_literal: true

require 'json'

# rubocop:disable Metrics/BlockLength
namespace :better_together do
  namespace :people do
    desc 'Dry-run or execute a reviewed hard deletion for one or more people'
    task hard_delete: :environment do
      parse_ids = lambda do |value|
        value.to_s.split(',').map(&:strip).reject(&:blank?).uniq
      end

      person_ids = parse_ids.call(ENV.fetch('PERSON_IDS', nil))
      deletion_request_ids = parse_ids.call(ENV.fetch('DELETION_REQUEST_IDS', nil))
      preserve_person_ids = parse_ids.call(ENV.fetch('PRESERVE_PERSON_IDS', nil))
      reviewer_id = ENV['REVIEWED_BY_ID'].presence
      reason = ENV['REASON'].presence
      write_enable = ActiveModel::Type::Boolean.new.cast(ENV.fetch('WRITE_ENABLE', nil))

      raise ArgumentError, 'Provide PERSON_IDS or DELETION_REQUEST_IDS' if person_ids.empty? && deletion_request_ids.empty?

      reviewer = reviewer_id && BetterTogether::Person.find(reviewer_id)
      request_map = BetterTogether::PersonDeletionRequest.where(id: deletion_request_ids).index_by { |request| request.person_id.to_s }
      explicit_people = BetterTogether::Person.where(id: person_ids)
      request_people = request_map.values.map(&:person)
      people = (explicit_people.to_a + request_people).index_by { |person| person.id.to_s }

      raise ActiveRecord::RecordNotFound, 'No matching people found' if people.empty?

      preserved_targets = people.values.select { |person| preserve_person_ids.include?(person.id.to_s) }
      unless preserved_targets.empty?
        raise ArgumentError,
              "Refusing to delete preserved people: #{preserved_targets.map(&:id).join(', ')}"
      end

      results = people.values.map do |person|
        request = request_map[person.id.to_s]

        if write_enable
          audit = BetterTogether::PersonHardDeletionExecutor.call(
            person: person,
            person_deletion_request: request,
            reviewed_by: reviewer,
            reason: reason
          )

          {
            mode: 'hard_delete',
            person_id: person.id,
            person_deletion_request_id: request&.id,
            audit_id: audit.id,
            status: audit.status,
            execution_snapshot: audit.execution_snapshot
          }
        else
          {
            mode: 'dry_run',
            person_id: person.id,
            person_deletion_request_id: request&.id,
            inventory: BetterTogether::PersonHardDeletionInventory.call(person: person)
          }
        end
      end

      puts JSON.pretty_generate(
        write_enable: write_enable,
        reviewer_id: reviewer&.id,
        reason: reason,
        count: results.size,
        results: results
      )
    end
  end
end
# rubocop:enable Metrics/BlockLength
