# frozen_string_literal: true

module BetterTogether
  # Canonical CE data envelope for portable export/import between platforms.
  class Seed < ApplicationRecord # rubocop:todo Metrics/ClassLength
    self.table_name = 'better_together_seeds'
    self.inheritance_column = :type

    DEFAULT_ROOT_KEY = 'better_together'

    include Creatable
    include Identifier
    include Privacy

    # Security configurations
    MAX_FILE_SIZE = 10.megabytes
    PERMITTED_YAML_CLASSES = [Time, Date, DateTime, Symbol].freeze
    ALLOWED_SEED_DIRECTORIES = %w[config/seeds].freeze

    has_one_attached :yaml_file

    belongs_to :seedable, polymorphic: true, optional: true

    has_many :seed_plantings, foreign_key: :seed_id, dependent: :destroy

    validates :type, :identifier, :version, :created_by, :seeded_at,
              :description, :origin, :payload, presence: true

    # Fields whose changes warrant re-exporting the YAML file.
    # A touch (only updated_at changes) must NOT trigger re-attachment;
    # that would recurse via Active Storage's belongs_to touch: true.
    YAML_CONTENT_FIELDS = %w[payload version description origin seeded_at created_by type identifier].freeze

    after_create_commit :attach_yaml_file
    after_update_commit :attach_yaml_file_on_content_change

    # -------------------------------------------------------------
    # Security Validation Methods
    # -------------------------------------------------------------

    def self.validate_file_path!(file_path)
      normalized_path = File.expand_path(file_path)
      original_path = file_path.to_s

      raise SecurityError, "File path contains path traversal characters: #{file_path}" if original_path.include?('..')

      allowed = ALLOWED_SEED_DIRECTORIES.any? do |allowed_dir|
        absolute_allowed_dir = File.expand_path(allowed_dir, Rails.root)
        normalized_path.start_with?(absolute_allowed_dir)
      end

      return if allowed

      raise SecurityError,
            "File path '#{file_path}' is not within allowed seed directories: #{ALLOWED_SEED_DIRECTORIES.join(', ')}"
    end

    def self.validate_file_size!(file_path)
      file_size = File.size(file_path)
      return unless file_size > MAX_FILE_SIZE

      raise SecurityError, "File size #{file_size} bytes exceeds maximum allowed size of #{MAX_FILE_SIZE} bytes"
    end

    def self.safe_load_yaml_file(file_path)
      YAML.safe_load_file(
        file_path,
        permitted_classes: PERMITTED_YAML_CLASSES,
        aliases: false,
        symbolize_names: false
      )
    rescue Psych::DisallowedClass => e
      raise SecurityError, "Unsafe class detected in YAML: #{e.message}"
    rescue Psych::BadAlias => e
      raise SecurityError, "YAML aliases are not permitted: #{e.message}"
    end

    # -------------------------------------------------------------
    # Scopes
    # -------------------------------------------------------------
    scope :by_type, ->(type) { where(type: type) }
    scope :by_identifier, ->(identifier) { where(identifier:) }
    scope :latest_first, -> { order(seeded_at: :desc, created_at: :desc) }
    scope :latest_version, ->(type, identifier) { by_type(type).by_identifier(identifier).latest_first.limit(1) }
    scope :latest, -> { latest_first.limit(1) }

    # -------------------------------------------------------------
    # Accessor overrides for origin/payload => Indifferent Access
    # -------------------------------------------------------------
    def origin
      super&.with_indifferent_access || {}
    end

    def payload
      super&.with_indifferent_access || {}
    end

    # -------------------------------------------------------------
    # Instance helpers
    # -------------------------------------------------------------
    def contributors
      origin[:contributors] || []
    end

    def platforms
      origin[:platforms] || []
    end

    def payload_data
      payload[:payload].presence || payload
    end

    def lane
      origin[:lane].presence || payload_data[:lane]
    end

    def private_linked?
      lane == 'private_linked'
    end

    def platform_shared?
      lane == 'platform_shared'
    end

    # -------------------------------------------------------------
    # plant = internal DB creation (used by import)
    # -------------------------------------------------------------
    def self.plant(type:, identifier:, version:, metadata:, content:) # rubocop:todo Metrics/MethodLength
      create!(
        type: type,
        identifier: identifier,
        version: version,
        created_by: metadata[:created_by],
        seeded_at: metadata[:created_at],
        description: metadata[:description],
        origin: metadata[:origin],
        payload: content,
        seedable_type: metadata[:seedable_type],
        seedable_id: metadata[:seedable_id]
      )
    end

    # -------------------------------------------------------------
    # import = read a seed and store in DB
    # -------------------------------------------------------------
    def self.import(seed_data, root_key: DEFAULT_ROOT_KEY) # rubocop:todo Metrics/MethodLength
      data = seed_data.deep_symbolize_keys.fetch(root_key.to_sym)
      metadata = data.fetch(:seed)
      content = data.except(:version, :seed)

      plant(
        type: metadata.fetch(:type),
        identifier: metadata.fetch(:identifier),
        version: data.fetch(:version),
        metadata: {
          created_by: metadata.fetch(:created_by),
          created_at: Time.iso8601(metadata.fetch(:created_at)),
          description: metadata.fetch(:description),
          origin: metadata.fetch(:origin),
          seedable_type: metadata[:seedable_type],
          seedable_id: metadata[:seedable_id]
        },
        content: content
      )
    end

    # -------------------------------------------------------------
    # import_or_update! = upsert by type+identifier
    # -------------------------------------------------------------
    def self.import_or_update!(seed_data, root_key: DEFAULT_ROOT_KEY)
      data = seed_data.deep_symbolize_keys.fetch(root_key.to_sym)
      record = find_or_build_from_data(data)
      record.assign_attributes(seed_record_attributes(data))
      record.save!
      record
    end

    def self.find_or_build_from_data(data)
      metadata = data.fetch(:seed)
      find_or_initialize_by(
        type: metadata.fetch(:type, name),
        identifier: metadata.fetch(:identifier)
      )
    end

    def self.seed_record_attributes(data)
      metadata = data.fetch(:seed)
      {
        version: data.fetch(:version),
        created_by: metadata.fetch(:created_by),
        seeded_at: Time.iso8601(metadata.fetch(:created_at)),
        description: metadata.fetch(:description),
        origin: metadata.fetch(:origin),
        payload: data.except(:version, :seed),
        seedable_type: metadata[:seedable_type],
        seedable_id: metadata[:seedable_id]
      }
    end

    # -------------------------------------------------------------
    # Enhanced planting with validation and transaction safety
    # -------------------------------------------------------------
    def self.plant_with_validation(seed_data, options = {}) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      root_key = options.delete(:root_key) || DEFAULT_ROOT_KEY

      seed_planting = create_seed_planting(options)
      seed_planting&.mark_started!

      begin
        validate_seed_structure!(seed_data, root_key)

        result = transaction do
          import(seed_data, root_key: root_key)
        end
        update_seed_planting_success(seed_planting, result) if seed_planting
        result
      rescue StandardError => e
        update_seed_planting_failure(seed_planting, e) if seed_planting
        raise
      end
    rescue ActiveRecord::RecordInvalid => e
      raise "Validation failed during import: #{e.message}"
    rescue KeyError => e
      raise "Missing required field in seed data: #{e.message}"
    rescue ArgumentError => e
      raise ArgumentError, "Invalid data format in seed: #{e.message}"
    end

    # -------------------------------------------------------------
    # Seed structure validation
    # -------------------------------------------------------------
    def self.validate_seed_structure!(seed_data, root_key) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      raise ArgumentError, "Seed data must be a hash, got #{seed_data.class}" unless seed_data.is_a?(Hash)

      unless seed_data.key?(root_key.to_s) || seed_data.key?(root_key.to_sym)
        raise ArgumentError, "Seed data missing root key: #{root_key}"
      end

      data = seed_data.deep_symbolize_keys.fetch(root_key.to_sym)

      %i[version seed].each do |field|
        raise ArgumentError, "Seed data missing required field: #{field}" unless data.key?(field)
      end

      seed_metadata = data[:seed]
      %i[type identifier created_by created_at description origin].each do |field|
        raise ArgumentError, "Seed metadata missing required field: #{field}" unless seed_metadata.key?(field)
      end

      return if data[:version].to_s.match?(/^\d+\.\d+/)

      raise ArgumentError, "Invalid version format: #{data[:version]}. Expected format: 'X.Y'"
    end

    # -------------------------------------------------------------
    # Seed planting tracking helpers
    # -------------------------------------------------------------
    def self.create_seed_planting(options) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      return nil unless options[:track_planting]

      person = find_person_for_planting(options)

      metadata = options.except(:track_planting, :planted_by, :planted_by_id)
      metadata = { 'created_at' => Time.current.iso8601 } if metadata.blank?

      planting_attrs = {
        status: 'pending',
        planting_type: 'seed',
        privacy: 'private',
        metadata: metadata
      }

      planting_attrs[:planted_by] = person if person

      SeedPlanting.create!(planting_attrs)
    rescue StandardError => e
      Rails.logger.error "Failed to create seed planting record: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}" if e.backtrace
      nil
    end

    def self.update_seed_planting_success(seed_planting, result)
      return unless seed_planting

      seed_planting.update!(seed_id: result.id) if result.respond_to?(:id) && result.id.present?
      seed_planting.mark_completed!(
        result.is_a?(Hash) ? result : { status: 'completed' }
      )
      Rails.logger.info "Seed planting completed successfully for ID: #{seed_planting.id}"
    end

    def self.update_seed_planting_failure(seed_planting, error)
      return unless seed_planting

      seed_planting.mark_failed!(
        error,
        {
          error_class: error.class.name,
          error_backtrace: error.backtrace&.first(10),
          failed_at: Time.current
        }
      )
      Rails.logger.error "Seed planting failed for ID: #{seed_planting.id}: #{error.message}"
    end

    def self.find_person_for_planting(options = {})
      return options[:planted_by] if options[:planted_by].is_a?(Person)
      return Person.find(options[:planted_by_id]) if options[:planted_by_id]

      nil
    end

    # -------------------------------------------------------------
    # export = produce a structured hash including seedable info
    # -------------------------------------------------------------
    def export(root_key: DEFAULT_ROOT_KEY) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      seed_obj = {
        type: type,
        identifier: identifier,
        created_by: created_by,
        created_at: seeded_at.iso8601,
        description: description,
        origin: origin.deep_symbolize_keys
      }

      seed_obj[:seedable_type] = seedable_type if seedable_type.present?
      seed_obj[:seedable_id]   = seedable_id if seedable_id.present?

      {
        root_key => {
          version: version,
          seed: seed_obj,
          **payload.deep_symbolize_keys
        }
      }
    end

    def export_yaml(root_key: DEFAULT_ROOT_KEY)
      export(root_key: root_key).deep_stringify_keys.to_yaml
    end

    def versioned_file_name
      timestamp = seeded_at.utc.strftime('%Y%m%d%H%M%S')
      "#{type.demodulize.underscore}_#{identifier}_v#{version}_#{timestamp}.yml"
    end

    # -------------------------------------------------------------
    # Secure seed loading with comprehensive validation
    # -------------------------------------------------------------
    def self.load_seed(source, root_key: DEFAULT_ROOT_KEY) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      if File.exist?(source)
        begin
          validate_file_path!(source)
          validate_file_size!(source)
          seed_data = safe_load_yaml_file(source)
          return plant_with_validation(seed_data, { source: source, root_key: root_key })
        rescue SecurityError => e
          Rails.logger.error "Security violation in seed loading: #{e.message}"
          raise
        rescue StandardError => e
          raise "Error loading seed from file '#{source}': #{e.message}"
        end
      end

      path = Rails.root.join('config', 'seeds', "#{source}.yml").to_s
      raise "Seed file not found for '#{source}' at path '#{path}'" unless File.exist?(path)

      begin
        validate_file_path!(path)
        validate_file_size!(path)
        seed_data = safe_load_yaml_file(path)
        plant_with_validation(seed_data, { source: path, root_key: root_key })
      rescue SecurityError => e
        Rails.logger.error "Security violation in seed loading: #{e.message}"
        raise
      rescue StandardError => e
        raise "Error loading seed from namespace '#{source}' at path '#{path}': #{e.message}"
      end
    end

    # -------------------------------------------------------------
    # Attach the exported YAML as an Active Storage file
    # -------------------------------------------------------------
    def attach_yaml_file_on_content_change
      attach_yaml_file if previous_changes.keys.intersect?(YAML_CONTENT_FIELDS)
    end

    def attach_yaml_file
      # Guard against infinite recursion: Active Storage's `belongs_to :record,
      # touch: true` fires after_update_commit on a *different Ruby instance* of
      # this record, so an instance-variable guard (@attaching_yaml_file) fails.
      # A thread-local keyed by record id is process-safe and instance-safe.
      key = :"attach_yaml_file_#{id}"
      return if Thread.current[key]

      Thread.current[key] = true
      yml_data = export_yaml
      yaml_file.attach(
        io: StringIO.new(yml_data),
        filename: versioned_file_name,
        content_type: 'text/yaml'
      )
    ensure
      Thread.current[key] = nil
    end
  end
end
