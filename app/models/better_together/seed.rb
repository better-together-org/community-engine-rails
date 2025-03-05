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

    # 1) Make sure you have Active Storage set up in your app
    #    This attaches a single YAML file to each seed record
    has_one_attached :yaml_file

    # 2) Polymorphic association: optional
    belongs_to :seedable, polymorphic: true, optional: true

    validates :type, :identifier, :version, :created_by, :seeded_at,
              :description, :origin, :payload, presence: true

    after_create_commit :attach_yaml_file
    after_update_commit :attach_yaml_file

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
    # load_seed for file or named namespace
    # -------------------------------------------------------------
    def self.load_seed(source, root_key: DEFAULT_ROOT_KEY) # rubocop:todo Metrics/MethodLength
      # 1) Direct file path
      if File.exist?(source)
        begin
          seed_data = YAML.load_file(source)
          return import(seed_data, root_key: root_key)
        rescue StandardError => e
          raise "Error loading seed from file '#{source}': #{e.message}"
        end
      end

      # 2) 'namespace' approach => config/seeds/#{source}.yml
      path = Rails.root.join('config', 'seeds', "#{source}.yml").to_s
      raise "Seed file not found for '#{source}' at path '#{path}'" unless File.exist?(path)

      begin
        seed_data = YAML.load_file(path)
        import(seed_data, root_key: root_key)
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
