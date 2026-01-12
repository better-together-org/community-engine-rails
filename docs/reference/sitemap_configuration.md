# Sitemap Configuration

The Better Together Community Engine provides a flexible sitemap system that allows host applications to include core platform resources while adding their own custom content.

## Quick Start

### 1. Create `config/sitemap.rb` in your host application:

```ruby
# config/sitemap.rb
require 'better_together/sitemap_helper'

SitemapGenerator::Sitemap.default_host = "https://yourdomain.com"

SitemapGenerator::Sitemap.create do
  # Include all Better Together core resources
  BetterTogether::SitemapHelper.add_better_together_resources(self)
  
  # Add your custom resources
  Article.published.find_each do |article|
    add article_path(article), lastmod: article.updated_at
  end
end
```

### 2. Generate the sitemap:

```bash
rake sitemap:refresh
```

The sitemap will be generated and automatically uploaded to Active Storage, making it available at `/sitemap.xml.gz`.

## Core Resources

The `BetterTogether::SitemapHelper` module provides methods to include platform resources:

### Add All Resources

```ruby
BetterTogether::SitemapHelper.add_better_together_resources(self)
```

This includes:
- Home page
- Communities (index + individual pages)
- Conversations (index + individual pages)
- Posts (index + published posts)
- Events (index + individual events)
- Pages (published public pages only)

### Selective Inclusion

Include only specific resource types:

```ruby
SitemapGenerator::Sitemap.create do
  # Add only pages and posts from Better Together
  BetterTogether::SitemapHelper.add_pages(self)
  BetterTogether::SitemapHelper.add_posts(self)
  
  # Add your own resources
  Product.active.find_each do |product|
    add product_path(product), lastmod: product.updated_at
  end
end
```

### Available Methods

- `add_better_together_resources(sitemap)` - All core resources
- `add_home_page(sitemap)` - Platform home page
- `add_communities(sitemap)` - Communities index and pages
- `add_conversations(sitemap)` - Conversations index and pages
- `add_posts(sitemap)` - Posts index and published posts
- `add_events(sitemap)` - Events index and pages
- `add_pages(sitemap)` - Published public pages

## Automatic Refresh

The sitemap is automatically refreshed when:
- A page is published or unpublished (via `PagePublishJob`)
- Manual refresh via rake task: `rake sitemap:refresh`

## Configuration

### Environment Variables

```bash
APP_PROTOCOL=https
APP_HOST=yourdomain.com
```

### Custom Sitemap Location

By default, sitemaps are stored in Active Storage and served from `/sitemap.xml.gz`. The physical sitemap is also written to `public/sitemap.xml.gz` during generation.

## Examples

### Basic Host App Configuration

```ruby
# config/sitemap.rb
require 'better_together/sitemap_helper'

SitemapGenerator::Sitemap.default_host = "https://myapp.com"

SitemapGenerator::Sitemap.create do
  BetterTogether::SitemapHelper.add_better_together_resources(self)
end
```

### Advanced Configuration with Custom Resources

```ruby
# config/sitemap.rb
require 'better_together/sitemap_helper'

SitemapGenerator::Sitemap.default_host = ENV['SITEMAP_HOST']
SitemapGenerator::Sitemap.sitemaps_path = 'sitemaps/'

SitemapGenerator::Sitemap.create do
  # Better Together core resources
  BetterTogether::SitemapHelper.add_home_page(self)
  BetterTogether::SitemapHelper.add_pages(self)
  BetterTogether::SitemapHelper.add_posts(self)
  
  # Custom application resources
  add about_path
  add terms_path
  add privacy_path
  
  # Dynamic resources
  Category.active.find_each do |category|
    add category_path(category), 
        priority: 0.7,
        changefreq: 'weekly',
        lastmod: category.updated_at
  end
  
  Product.published.find_each do |product|
    add product_path(product),
        priority: 0.9,
        changefreq: 'daily',
        lastmod: product.updated_at,
        images: [{ loc: product.image_url, title: product.name }]
  end
end
```

### Excluding Certain Better Together Resources

```ruby
# config/sitemap.rb
require 'better_together/sitemap_helper'

SitemapGenerator::Sitemap.default_host = "https://myapp.com"

SitemapGenerator::Sitemap.create do
  # Include only specific Better Together resources
  BetterTogether::SitemapHelper.add_home_page(self)
  BetterTogether::SitemapHelper.add_pages(self)
  BetterTogether::SitemapHelper.add_posts(self)
  # Skip: communities, conversations, events
  
  # Add your resources
  MyModel.all.each do |item|
    add my_model_path(item)
  end
end
```

## Testing

The sitemap helper is fully tested. Host applications should test their sitemap configuration:

```ruby
# spec/jobs/sitemap_refresh_job_spec.rb
require 'rails_helper'

RSpec.describe SitemapRefreshJob do
  before do
    stub_request(:get, /google.com\/webmasters\/tools\/ping/).to_return(status: 200)
  end

  it 'includes custom resources in the sitemap' do
    product = create(:product)
    
    described_class.perform_now
    
    sitemap_data = File.read(Rails.root.join('public', 'sitemap.xml.gz'))
    xml = Zlib::GzipReader.new(StringIO.new(sitemap_data)).read
    
    expect(xml).to include(product.slug)
  end
end
```

## Deployment

### Dokku / Heroku

The sitemap is automatically generated and stored in Active Storage, making it available across all dynos/containers without needing shared file storage.

### Custom Storage

To use S3 or another Active Storage service, configure it in `config/storage.yml`:

```yaml
amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: us-east-1
  bucket: my-bucket
```

Then set `config.active_storage.service = :amazon` in your environment configuration.

## Troubleshooting

### Sitemap not updating

Run the refresh job manually:
```bash
rails runner "BetterTogether::SitemapRefreshJob.perform_now"
```

### Missing resources

Ensure your sitemap configuration includes the desired helper methods and that resources meet the inclusion criteria (published, public, etc.).

### File not accessible

Check that the sitemap file is attached to the platform's Sitemap record:
```ruby
platform = BetterTogether::Platform.find_by(host: true)
sitemap = BetterTogether::Sitemap.current(platform)
sitemap.file.attached? # Should be true
```
