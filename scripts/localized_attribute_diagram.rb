# frozen_string_literal: true

require 'ripper'

# Draws a Mermaid class diagram of the models that carry localized (Mobility) attributes, with each
# attribute's storage type. Self-contained on purpose: it needs only Ruby, ActiveRecord and Mobility, so
# host apps copy this one file next to their own entry script and need no newer gem.
#
# Models and types come from live Mobility reflection. Which declarations count, and which of them name
# no type, comes from a static scan of `translates` calls under the scope roots, so an app drawing only its
# own attributes ignores the ones a gem declares.
#
# Output is deterministic (sorted, no timestamps) so a check can compare it with the committed file.
class LocalizedAttributeDiagram
  # One `translates` call found in source.
  Declaration = Struct.new(:file, :line, :nesting, :attributes, :explicit_type, :dynamic, keyword_init: true) do
    def location = "#{file}:#{line}"
  end

  # One attribute of one model, as drawn.
  Entry = Struct.new(:model, :attribute, :type, :untyped, keyword_init: true)

  # Finds `translates` and `translates_attached` calls in Ruby source.
  class Scanner
    CALLS = %w[translates translates_attached].freeze

    def self.scan_source(source, file: '(source)')
      new(source, file).declarations
    end

    def self.scan_roots(roots, base: Dir.pwd)
      files = roots.flat_map { |root| Dir.glob(File.join(root, '{app,lib,config}/**/*.rb')) }
      files.uniq.sort.flat_map do |path|
        scan_source(File.read(path), file: path.delete_prefix("#{base}/"))
      end
    end

    def initialize(source, file)
      @file = file
      @declarations = []
      sexp = Ripper.sexp(source)
      walk(sexp, []) if sexp
    end

    attr_reader :declarations

    private

    def walk(node, nesting)
      return unless node.is_a?(Array)

      return walk_scope(node, nesting) if %i[class module].include?(node.first)
      return if %i[command method_add_arg fcall].include?(node.first) && record?(node, nesting)

      node.each { |child| walk(child, nesting) }
    end

    def walk_scope(node, nesting)
      name = const_name(node[1])
      inner = name.start_with?('::') ? [name.delete_prefix('::')] : nesting + [name]
      node[2..].each { |child| walk(child, inner) }
    end

    def const_name(node)
      case node.first
      when :const_ref, :var_ref then node[1][1]
      when :top_const_ref then "::#{node[1][1]}"
      when :const_path_ref then "#{const_name(node[1])}::#{node[2][1]}"
      when :@const then node[1]
      else node.inspect
      end
    end

    def record?(node, nesting)
      name, args = call_parts(node)
      return false unless CALLS.include?(name)

      @declarations << build(name, node, args, nesting)
      true
    end

    def call_parts(node)
      case node.first
      when :command then [ident(node[1]), node[2]]
      when :fcall then [ident(node[1]), nil]
      else
        call = node[1]
        call.first == :fcall ? [ident(call[1]), node[2]] : [nil, nil]
      end
    end

    def ident(node)
      node.is_a?(Array) && node.first == :@ident ? node[1] : nil
    end

    def build(name, node, args, nesting)
      positional, options = split_args(args)
      Declaration.new(
        file: @file, line: line_of(node), nesting: nesting.join('::'),
        attributes: positional.map { |a| symbol_name(a) }.compact,
        explicit_type: name == 'translates_attached' || explicit?(options),
        dynamic: positional.any? { |a| symbol_name(a).nil? }
      )
    end

    def split_args(args)
      list = flatten_args(args)
      options = list.select { |a| a.first == :bare_assoc_hash }
      [list - options, options]
    end

    def flatten_args(args)
      return [] unless args.is_a?(Array)
      return flatten_args(args[1]) if %i[arg_paren args_add_block].include?(args.first)
      return flatten_args(args[1]) + [[:splat]] if args.first == :args_add_star
      return args.grep(Array) if args.first.is_a?(Array)

      []
    end

    def explicit?(options)
      options.any? do |hash|
        hash[1].any? { |pair| pair.first == :assoc_new && %w[type: backend:].include?(pair[1][1]) }
      end
    end

    def symbol_name(node)
      return nil unless node.first == :symbol_literal

      node[1][1][1]
    end

    def line_of(node)
      found = node.flatten(3).find { |n| n.is_a?(Array) && n.first == :@ident } || []
      found.dig(2, 0) || 0
    end
  end

  attr_reader :entries, :unresolved

  # models: loaded ActiveRecord classes; declarations: Scanner results for the scope.
  def initialize(models:, declarations:, title:, locales: I18n.available_locales)
    @title = title
    @locales = locales.map(&:to_s).sort
    @declarations = declarations
    @models = models
    @unresolved = []
    @entries = build_entries
  end

  def untyped_entries = entries.select(&:untyped)

  def untyped_declarations = @declarations.reject(&:explicit_type).reject { |d| d.attributes.empty? }

  def to_mermaid
    lines = header
    grouped_entries.each do |group, models|
      lines << "  namespace #{group} {"
      models.each { |model, items| lines.concat(class_block(model, items)) }
      lines << '  }'
    end
    "#{lines.join("\n")}\n"
  end

  # True when the file on disk equals the freshly generated diagram.
  def current?(path)
    File.exist?(path) && File.read(path) == to_mermaid
  end

  private

  def header
    [
      "%% #{@title}: localized (Mobility) attributes by model, grouped by namespace.",
      '%% Generated by scripts/export_localized_attribute_diagram.rb. Do not edit by hand.',
      "%% Every attribute has a reader and writer per locale: <attribute>_#{@locales.join(', _')}.",
      '%% Types: string and text (key_value tables), rich_text (Action Text), attachment (attachments backend).',
      '%% UNTYPED marks a translates call with no type: or backend:, which silently takes the global default.',
      'classDiagram',
      '  direction LR'
    ]
  end

  def grouped_entries
    by_namespace = entries.group_by(&:model).group_by { |model, _| namespace_of(model) }
    by_namespace.sort_by(&:first).map { |group, rows| [group, rows.sort_by(&:first)] }
  end

  def namespace_of(model)
    parts = model.delete_prefix('BetterTogether::').split('::')
    return parts.first if parts.length > 1 || !model.start_with?('BetterTogether::')

    'Core'
  end

  def class_block(model, items)
    id = model.gsub('::', '_')
    block = ["    class #{id}[\"#{model.delete_prefix('BetterTogether::')}\"] {"]
    items.sort_by(&:attribute).each do |e|
      block << "      +#{e.attribute} : #{e.type}#{' UNTYPED' if e.untyped}"
    end
    block << '    }'
  end

  def build_entries
    rows = {}
    @declarations.each { |decl| apply(decl, rows) }
    rows.values.sort_by { |e| [e.model, e.attribute] }
  end

  def apply(decl, rows)
    owners = owners_of(decl)
    @unresolved << decl if owners.empty? || decl.dynamic
    owners.product(decl.attributes).each do |model, attr|
      record_entry(rows, model, attr, decl) if model.mobility_attributes.include?(attr)
    end
  end

  def record_entry(rows, model, attr, decl)
    key = [model.name, attr]
    untyped = !decl.explicit_type || rows[key]&.untyped || false
    rows[key] = Entry.new(model: model.name, attribute: attr, type: type_of(model, attr), untyped: untyped)
  end

  def owners_of(decl)
    const = resolve(decl.nesting)
    return [] unless const

    @models.select { |m| m.name && m <= const && m.respond_to?(:mobility_attributes) }
  end

  def resolve(nesting)
    parts = nesting.split('::')
    parts.length.downto(1) do |n|
      const = parts.first(n).join('::').safe_constantize
      return const if const
    end
    nil
  end

  def type_of(model, attribute)
    options = model.mobility_backend_class(attribute).options
    backend = Array(options[:backend]).first
    case backend
    when :key_value then (options[:type] || :string).to_s
    when :action_text then 'rich_text'
    when :attachments then 'attachment'
    else backend.to_s
    end
  end
end
