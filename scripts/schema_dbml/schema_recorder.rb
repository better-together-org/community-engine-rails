# frozen_string_literal: true

# Collects what ActiveRecord::Schema.define would send to the connection.
class SchemaRecorder
  Column = Struct.new(:name, :type, :null, :default, :limit, :array)
  Table = Struct.new(:name, :primary_key, :columns, :indexes)
  Index = Struct.new(:columns, :name, :unique)
  Reference = Struct.new(:from_table, :to_table, :column, :primary_key, :name)

  attr_reader :tables, :references, :extensions, :version

  def initialize
    @tables = []
    @references = []
    @extensions = []
  end

  def define(version:, &)
    @version = version
    instance_eval(&)
  end

  def enable_extension(name)
    @extensions << name
  end

  def create_table(name, id: :bigserial, **_options)
    table = Table.new(name, id, [], [])
    table.columns << Column.new('id', pk_type(id), false, nil, nil, false) unless id == false
    yield TableRecorder.new(table)
    @tables << table
  end

  def add_foreign_key(from, to, **options)
    column = options[:column] || "#{singular(to.to_s)}_id"
    @references << Reference.new(from, to, column, options.fetch(:primary_key, 'id'), options[:name])
  end

  # Anything else in schema.rb (comments, check constraints, views) does not change the diagram.
  def method_missing(*, **, &)
    nil
  end

  def respond_to_missing?(*)
    true
  end

  private

  # schema.rb omits `column:` when it follows the Rails convention (singular table name + _id).
  def singular(name)
    return "#{name.delete_suffix('ies')}y" if name.end_with?('ies')

    name.delete_suffix('s')
  end

  def pk_type(id)
    id == :uuid ? 'uuid' : id.to_s
  end

  # Receives the `t.<type> "name", options` calls inside a create_table block.
  class TableRecorder
    def initialize(table)
      @table = table
    end

    def index(columns, name: nil, unique: false, **_options)
      @table.indexes << Index.new(Array(columns), name, unique)
    end

    def method_missing(type, name = nil, **options, &)
      return super unless name.is_a?(String)

      @table.columns << Column.new(name, type.to_s, options.fetch(:null, true), options[:default], options[:limit],
                                   options.fetch(:array, false))
    end

    def respond_to_missing?(_name, _include_private = false)
      true
    end
  end
end
