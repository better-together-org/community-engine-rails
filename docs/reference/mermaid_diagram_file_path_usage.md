# Mermaid Diagram File Path Feature

## Overview

The `diagram_file_path` feature allows you to reference `.mmd` (Mermaid) diagram files instead of embedding diagram source code directly. This is **fully implemented and working** - perfect for building documentation pages!

## How It Works

### Model Attributes

`BetterTogether::Content::MermaidDiagram` supports:
- `diagram_source` (text) - Inline mermaid code
- `diagram_file_path` (string) - Path to `.mmd` file
- `caption` (string) - Diagram caption
- `theme` (string) - default, dark, forest, neutral
- `auto_height` (boolean) - Auto-adjust height

### Content Resolution

The `content` method automatically loads from:
1. **`diagram_source`** if present (inline code takes priority)
2. **`diagram_file_path`** if present (loads from file)
3. Empty string if neither provided

### File Path Resolution

Paths can be:
- **Absolute**: `/full/path/to/diagram.mmd`
- **Relative to Rails.root**: `docs/diagrams/source/my_diagram.mmd`

## Usage Examples

### Create Diagram from File

```ruby
# Create a mermaid diagram that loads from file
diagram = BetterTogether::Content::MermaidDiagram.create!(
  diagram_file_path: 'docs/diagrams/source/user_flow.mmd',
  caption: 'User Registration Flow',
  theme: 'default',
  auto_height: true
)

# Add to a page
page = BetterTogether::Page.find_by(slug: 'documentation')
page.page_blocks.create!(
  block: diagram,
  position: 1
)
```

### Reference Documentation Diagrams

```ruby
# Load diagram from your existing documentation structure
diagram = BetterTogether::Content::MermaidDiagram.create!(
  diagram_file_path: 'docs/diagrams/source/person_blocks_flow.mmd',
  caption: 'Person Blocking Process Flow',
  theme: 'neutral'
)
```

### Validation

The model validates:
- ✅ At least one content source (diagram_source OR diagram_file_path)
- ✅ File exists if diagram_file_path provided
- ✅ File has `.mmd` extension
- ✅ Mermaid syntax is valid

### Example with Validation

```ruby
# This will fail validation - file doesn't exist
diagram = BetterTogether::Content::MermaidDiagram.new(
  diagram_file_path: 'nonexistent.mmd'
)
diagram.valid?
# => false
diagram.errors[:diagram_file_path]
# => ["file not found"]

# This will fail validation - wrong extension
diagram = BetterTogether::Content::MermaidDiagram.new(
  diagram_file_path: 'docs/readme.md'
)
diagram.valid?
# => false
diagram.errors[:diagram_file_path]
# => ["must be a .mmd file"]
```

## Building Documentation Pages

### Recommended Structure

```
docs/
  diagrams/
    source/
      system_a_flow.mmd
      system_b_architecture.mmd
      database_schema.mmd
    exports/
      png/
        system_a_flow.png
      svg/
        system_a_flow.svg
  systems/
    system_a.md
    system_b.md
```

### Creating Documentation Page with Diagrams

```ruby
# Create documentation page
doc_page = BetterTogether::Page.create!(
  title: 'System Architecture',
  slug: 'architecture-docs',
  published: true,
  privacy: 'public'
)

# Add text content
intro_text = BetterTogether::Content::Markdown.create!(
  markdown_source: '# System Architecture\n\nThis page describes our system architecture.'
)
doc_page.page_blocks.create!(block: intro_text, position: 1)

# Add diagram from file
arch_diagram = BetterTogether::Content::MermaidDiagram.create!(
  diagram_file_path: 'docs/diagrams/source/system_architecture.mmd',
  caption: 'High-level system architecture showing key components',
  theme: 'neutral',
  auto_height: true
)
doc_page.page_blocks.create!(block: arch_diagram, position: 2)

# Add more text
details_text = BetterTogether::Content::Markdown.create!(
  markdown_source: '## Component Details\n\nThe following sections describe each component...'
)
doc_page.page_blocks.create!(block: details_text, position: 3)

# Add database schema diagram
db_diagram = BetterTogether::Content::MermaidDiagram.create!(
  diagram_file_path: 'docs/diagrams/source/database_schema.mmd',
  caption: 'Database entity relationships',
  theme: 'default',
  auto_height: false
)
doc_page.page_blocks.create!(block: db_diagram, position: 4)
```

## Advantages for Documentation

1. **Single Source of Truth**: Diagram files live in `docs/` - one place to maintain
2. **Version Control**: `.mmd` files track changes in git
3. **Reusability**: Same diagram file can be referenced by multiple pages
4. **Export Compatibility**: Can still use `bin/render_diagrams` to generate PNG/SVG exports
5. **Live Updates**: Edit `.mmd` file, refresh page - changes appear immediately
6. **Validation**: Ensures diagrams exist and are valid before page renders

## API Usage

### Permitted Attributes

```ruby
BetterTogether::Content::MermaidDiagram.permitted_attributes
# => [:diagram_source, :diagram_file_path, :caption, :theme, :auto_height]
```

### Form Fields

```erb
<%= form_with model: @diagram, url: ... do |f| %>
  <%= f.label :diagram_file_path %>
  <%= f.text_field :diagram_file_path, 
                   placeholder: 'docs/diagrams/source/my_diagram.mmd' %>
  
  <%= f.label :caption %>
  <%= f.text_field :caption %>
  
  <%= f.label :theme %>
  <%= f.select :theme, 
               BetterTogether::Content::MermaidDiagram::VALID_THEMES,
               {}, { class: 'form-control' } %>
  
  <%= f.check_box :auto_height %>
  <%= f.label :auto_height, 'Auto-adjust height' %>
  
  <%= f.submit %>
<% end %>
```

## Current Limitations

- **PNG generation disabled**: The PNG fallback feature is commented out (future enhancement)
- **Requires JavaScript**: Diagrams render client-side with Mermaid.js
- **No noscript fallback**: Users without JavaScript see a note (PNG generation would fix this)

## Migration from Inline to File-Based

If you have diagrams with inline `diagram_source`, you can migrate to file-based:

```ruby
diagram = BetterTogether::Content::MermaidDiagram.find(id)

# Save current content to file
file_path = Rails.root.join('docs/diagrams/source/migrated_diagram.mmd')
File.write(file_path, diagram.content)

# Update to use file
diagram.update!(
  diagram_file_path: 'docs/diagrams/source/migrated_diagram.mmd',
  diagram_source: nil  # Clear inline source
)
```

## Summary

✅ **Fully Implemented**: `diagram_file_path` feature is production-ready  
✅ **Validated**: File existence, extension, and syntax checked  
✅ **Documentation-Ready**: Perfect for building doc pages with diagrams  
✅ **Flexible**: Supports both inline source and file paths  
✅ **Maintainable**: Single source of truth for diagram content
