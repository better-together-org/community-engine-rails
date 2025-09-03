# frozen_string_literal: true

module BetterTogether
  # Allows for import and export of data in a structured and standardized way
  class Seed < ApplicationRecord # rubocop:todo Metrics/ClassLength
    self.table_name = 'better_together_seeds'
    self.inheritance_column = :type # Defensive for STI safety

    include Creatable
    include Identifier
    include Privacy

    DEFAULT_ROOT_KEY = 'better_together'

    # Security configurations
    MAX_FILE_SIZE = 10.megabytes
    PERMITTED_YAML_CLASSES = [Time, Date, DateTime, Symbol].freeze
    ALLOWED_SEED_DIRECTORIES = %w[config/seeds].freeze

    # 1) Make sure you have Active Storage set up in your app
    #    This attaches a single YAML file to each seed record
    has_one_attached :yaml_file

    # 2) Polymorphic association: optional
    belongs_to :seedable, polymorphic: true, optional: true

    # 3) Track planting operations
    has_many :seed_plantings, foreign_key: :seed_id, dependent: :destroy

    validates :type, :identifier, :version, :created_by, :seeded_at,
              :description, :origin, :payload, presence: true

    after_create_commit :attach_yaml_file
    after_update_commit :attach_yaml_file

    # -------------------------------------------------------------
    # Security Validation Methods
    # -------------------------------------------------------------

    # Validates file path is within allowed directories
    def self.validate_file_path!(file_path)
      normalized_path = File.expand_path(file_path)
      original_path = file_path.to_s

      # Check for path traversal characters before normalization
      raise SecurityError, "File path contains path traversal characters: #{file_path}" if original_path.include?('..')

      # Check if path is within allowed directories
      allowed = ALLOWED_SEED_DIRECTORIES.any? do |allowed_dir|
        absolute_allowed_dir = File.expand_path(allowed_dir, Rails.root)
        normalized_path.start_with?(absolute_allowed_dir)
      end

      return if allowed

      raise SecurityError,
            "File path '#{file_path}' is not within allowed seed directories: #{ALLOWED_SEED_DIRECTORIES.join(', ')}"
    end

    # Validates file size is within limits
    def self.validate_file_size!(file_path)
      file_size = File.size(file_path)
      return unless file_size > MAX_FILE_SIZE

      raise SecurityError, "File size #{file_size} bytes exceeds maximum allowed size of #{MAX_FILE_SIZE} bytes"
    end

    # Safe YAML loading with restricted classes
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
    scope :by_identifier, ->(identifier) { where(identifier: identifier) }
    scope :latest_first, -> { order(created_at: :desc) }
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

    # Helpers for nested origin data
    def contributors
      origin[:contributors] || []
    end

    def platforms
      origin[:platforms] || []
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
    # Enhanced planting with validation and transaction safety
    # -------------------------------------------------------------
    def self.plant_with_validation(seed_data, options = {}) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      root_key = options.delete(:root_key) || DEFAULT_ROOT_KEY
      validate_seed_structure!(seed_data, root_key)

      transaction do
        seed_planting = create_seed_planting(options)
        seed_planting&.mark_started!

        begin
          result = import(seed_data, root_key: root_key)
          update_seed_planting_success(seed_planting, result) if seed_planting
          result
        rescue StandardError => e
          update_seed_planting_failure(seed_planting, e) if seed_planting
          raise
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      raise "Validation failed during import: #{e.message}"
    rescue KeyError => e
      raise "Missing required field in seed data: #{e.message}"
    rescue ArgumentError => e
      raise "Invalid data format in seed: #{e.message}"
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

      # Validate required top-level fields
      %i[version seed].each do |field|
        raise ArgumentError, "Seed data missing required field: #{field}" unless data.key?(field)
      end

      # Validate seed metadata
      seed_metadata = data[:seed]
      %i[type identifier created_by created_at description origin].each do |field|
        raise ArgumentError, "Seed metadata missing required field: #{field}" unless seed_metadata.key?(field)
      end

      # Validate version format
      return if data[:version].to_s.match?(/^\d+\.\d+/)

      raise ArgumentError, "Invalid version format: #{data[:version]}. Expected format: 'X.Y'"
    end

    # -------------------------------------------------------------
    # Seed planting tracking helpers
    # -------------------------------------------------------------
    def self.create_seed_planting(options)
      return nil unless options[:track_planting]

      # Create SeedPlanting record for tracking
      person = find_person_for_planting(options)
      SeedPlanting.create!(
        planted_by: person,
        status: 'pending',
        metadata: options.except(:track_planting)
      )
    rescue StandardError => e
      Rails.logger.error "Failed to create seed planting record: #{e.message}"
      nil
    end

    def self.update_seed_planting_success(seed_planting, result)
      return unless seed_planting

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

    # Find person for planting tracking
    def self.find_person_for_planting(options)
      return options[:planted_by] if options[:planted_by].is_a?(Person)

      if options[:planted_by_email]
        Person.joins(:person).find_by(persons: { email: options[:planted_by_email] })
      elsif options[:planted_by_id]
        Person.find_by(id: options[:planted_by_id])
      end
    end

    # -------------------------------------------------------------
    # export = produce a structured hash including seedable info
    # -------------------------------------------------------------
    # rubocop:todo Metrics/MethodLength
    def export(root_key: DEFAULT_ROOT_KEY) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      seed_obj = {
        type: type,
        identifier: identifier,
        created_by: created_by,
        created_at: seeded_at.iso8601,
        description: description,
        origin: origin.deep_symbolize_keys
      }

      # If seedable_type or seedable_id is present, include them
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
    # rubocop:enable Metrics/MethodLength

    # Export as YAML
    def export_yaml(root_key: DEFAULT_ROOT_KEY)
      export(root_key: root_key).deep_stringify_keys.to_yaml
    end

    # A recommended file name for the exported seed
    def versioned_file_name
      timestamp = seeded_at.utc.strftime('%Y%m%d%H%M%S')
      "#{type.demodulize.underscore}_#{identifier}_v#{version}_#{timestamp}.yml"
    end

    # -------------------------------------------------------------
    # Secure seed loading with comprehensive validation
    # -------------------------------------------------------------
    def self.load_seed(source, root_key: DEFAULT_ROOT_KEY) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      # 1) Direct file path
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

      # 2) 'namespace' approach => config/seeds/#{source}.yml
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
    def attach_yaml_file
      yml_data = export_yaml
      yaml_file.attach(
        io: StringIO.new(yml_data),
        filename: versioned_file_name,
        content_type: 'text/yaml'
      )
    end
  end
end
