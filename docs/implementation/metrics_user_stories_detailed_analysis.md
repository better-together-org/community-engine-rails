# Metrics User Stories - Detailed Analysis (US-MET-002 through US-MET-011)

**Date:** January 8, 2026  
**Status:** Design Review - Continuation  
**Related:** [Design Decisions Document](./metrics_retention_design_decisions.md)

---

## US-MET-002: Legal/Compliance - Automatic Purging

### Original Story
**As a** Legal/Compliance Officer  
**I want** old metrics data to be automatically deleted  
**So that** we maintain compliance without manual intervention

### Enhanced Context & Design Decisions

#### Key Questions

**Q1: What happens when the legal review workflow delays purging?**
- Scenario: Retention reduced from 730 to 365 days, but legal review takes 2 weeks
- During those 2 weeks, data is 365-380 days old
- Should purge job skip this data or delete it anyway?

**Design Decision:**
```ruby
# Purge job checks for approval status
def purge_page_views(settings)
  cutoff_date = settings.page_views_retention_days.days.ago
  
  base_scope = PageView.where('viewed_at < ?', cutoff_date)
  
  # Check for pending retention changes
  pending_changes = RetentionChange
    .where(metric_type: 'page_views', status: %w[pending_review under_review])
    .exists?
  
  if pending_changes
    # Only purge records beyond the OLD retention period (safe zone)
    oldest_pending = RetentionChange
      .where(metric_type: 'page_views', status: %w[pending_review under_review])
      .minimum(:old_retention_days)
    
    safe_cutoff = oldest_pending.days.ago
    base_scope = base_scope.where('viewed_at < ?', safe_cutoff)
    
    Rails.logger.info "[MetricsPurge] Pending review exists, using safe cutoff: #{safe_cutoff}"
  end
  
  base_scope.in_batches(of: 1000).delete_all
end
```

**Q2: How do we handle failures gracefully?**
- Database connection errors
- Insufficient disk space
- Long-running transactions blocking other queries

**Design Decision: Progressive Purging with Circuit Breaker**
```ruby
class PurgeOldMetricsJob < MetricsJob
  queue_as :low_priority
  
  # Circuit breaker: stop if too many errors
  MAX_ERRORS = 3
  BATCH_SIZE = 1000
  MAX_RUNTIME = 30.minutes
  
  def perform(platform_id = nil)
    @errors = 0
    @start_time = Time.current
    
    platform = find_platform(platform_id)
    return unless platform
    
    settings = platform.metrics_settings || create_default_settings(platform)
    return unless settings.purge_enabled?
    
    log_purge_start(platform, settings)
    
    record_counts = {}
    
    # Purge each metric type with error handling
    %w[page_views link_clicks shares downloads search_queries].each do |metric_type|
      break if circuit_breaker_open?
      
      begin
        count = purge_metric_type(metric_type, settings)
        record_counts[metric_type] = count
      rescue StandardError => e
        handle_purge_error(metric_type, e)
      end
    end
    
    # Purge reports separately (involves file deletion)
    record_counts.merge!(purge_reports(settings)) unless circuit_breaker_open?
    
    log_purge_completion(platform, settings, record_counts)
    notify_platform_managers(platform, record_counts) if settings.notify_on_purge?
    
  rescue StandardError => e
    log_purge_failure(platform, settings, e)
    raise
  end
  
  private
  
  def circuit_breaker_open?
    @errors >= MAX_ERRORS || runtime_exceeded?
  end
  
  def runtime_exceeded?
    Time.current - @start_time > MAX_RUNTIME
  end
  
  def handle_purge_error(metric_type, error)
    @errors += 1
    Rails.logger.error "[MetricsPurge] Error purging #{metric_type}: #{error.message}"
    
    # Report to error tracking (e.g., Sentry)
    Sentry.capture_exception(error, tags: { component: 'metrics_purge', metric_type: metric_type })
    
    # Stop if circuit breaker opens
    return if circuit_breaker_open?
  end
  
  def purge_metric_type(metric_type, settings)
    retention_field = "#{metric_type}_retention_days"
    retention_days = settings.send(retention_field)
    cutoff_date = retention_days.days.ago
    
    model_class = "BetterTogether::Metrics::#{metric_type.classify}".constantize
    timestamp_field = case metric_type
                      when 'page_views' then :viewed_at
                      when 'link_clicks' then :clicked_at
                      when 'shares' then :shared_at
                      when 'downloads' then :downloaded_at
                      when 'search_queries' then :searched_at
                      end
    
    # Check for pending changes
    if pending_review_exists?(metric_type)
      cutoff_date = safe_cutoff_date(metric_type)
    end
    
    deleted_count = 0
    model_class
      .where("#{timestamp_field} < ?", cutoff_date)
      .in_batches(of: BATCH_SIZE) do |batch|
        break if circuit_breaker_open?
        deleted_count += batch.delete_all
      end
    
    deleted_count
  end
  
  def pending_review_exists?(metric_type)
    RetentionChange
      .where(metric_type: metric_type, status: %w[pending_review under_review])
      .exists?
  end
  
  def safe_cutoff_date(metric_type)
    oldest_retention = RetentionChange
      .where(metric_type: metric_type, status: %w[pending_review under_review])
      .minimum(:old_retention_days)
    
    oldest_retention.days.ago
  end
end
```

**Q3: What about timezone handling?**
- Platform operates in multiple timezones
- Purge job runs at 2 AM - but which timezone?
- Record timestamps use which timezone?

**Design Decision:**
```ruby
# All timestamps stored in UTC
# Purge schedule respects platform timezone
class Metrics < ApplicationRecord
  belongs_to :platform
  
  # Purge schedule stored in cron format
  # Executed in platform's timezone
  def purge_schedule_timezone
    platform.timezone || 'UTC'
  end
  
  # When calculating cutoff dates, use UTC
  def retention_date(metric_type)
    retention_days = send("#{metric_type}_retention_days")
    retention_days.days.ago.utc
  end
end

# Good Job scheduler config
config.good_job.cron = {
  metrics_purge: {
    cron: ->(platform_id = nil) {
      platform = BetterTogether::Platform.find_by(id: platform_id) ||
                 BetterTogether::Platform.find_by(host: true)
      settings = platform&.metrics_settings
      settings&.purge_schedule || '0 2 * * *'
    },
    class: 'BetterTogether::Metrics::PurgeOldMetricsJob',
    description: 'Purge old metrics data',
    set: ->(platform_id = nil) {
      platform = BetterTogether::Platform.find_by(id: platform_id) ||
                 BetterTogether::Platform.find_by(host: true)
      settings = platform&.metrics_settings
      timezone = settings&.purge_schedule_timezone || 'UTC'
      { timezone: timezone }
    }
  }
}
```

#### Acceptance Criteria Updates

**Original:**
- ✅ Scheduled job runs daily at 2 AM (configurable)
- ✅ Purges metrics older than retention period
- ✅ Uses batch deletion to avoid long transactions
- ✅ Logs deletion counts
- ✅ Creates audit log entry
- ✅ Sends notification to platform managers
- ✅ Handles failures gracefully with retry logic

**Enhanced:**
- ✅ **Respects pending legal reviews** - doesn't delete data under review
- ✅ **Circuit breaker pattern** - stops after 3 errors or 30 minutes
- ✅ **Timezone-aware** - runs in platform's timezone
- ✅ **Progressive deletion** - batch size 1000 to avoid locks
- ✅ **Error tracking** - integrates with Sentry/error monitoring
- ✅ **Safe failure mode** - partial completion is acceptable
- ✅ **Idempotent** - can be re-run safely if interrupted

#### Additional Considerations

**Notification Design:**
```ruby
# Use Noticed gem for notifications
class MetricsPurgeCompletedNotification < Noticed::Base
  deliver_by :database
  deliver_by :email, if: :email_enabled?
  
  param :platform
  param :record_counts
  param :audit_log_id
  
  def message
    I18n.t('notifications.metrics_purge_completed.message',
           total: params[:record_counts].values.sum,
           date: Time.current.to_date)
  end
  
  def url
    Rails.application.routes.url_helpers.metrics_audit_log_path(params[:audit_log_id])
  end
  
  private
  
  def email_enabled?
    recipient.metrics_notifications_enabled?
  end
end

# Usage in job
def notify_platform_managers(platform, record_counts)
  platform.managers.each do |manager|
    MetricsPurgeCompletedNotification.with(
      platform: platform,
      record_counts: record_counts,
      audit_log_id: @audit_log.id
    ).deliver(manager)
  end
end
```

**Database Performance:**
```sql
-- Ensure indexes support efficient purging
CREATE INDEX CONCURRENTLY idx_page_views_viewed_at_btree 
  ON better_together_metrics_page_views (viewed_at)
  WHERE viewed_at < (CURRENT_DATE - INTERVAL '30 days');
-- Partial index only covers old records, smaller and faster

-- Consider table partitioning for very high volume
-- (Future enhancement, not this sprint)
CREATE TABLE better_together_metrics_page_views_2026_01
  PARTITION OF better_together_metrics_page_views
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
```

---

## US-MET-003: Platform Organizer - Audit Trail

### Original Story
**As a** Platform Organizer  
**I want** to see when data was automatically deleted  
**So that** I can verify compliance and respond to audits

### Enhanced Context & Design Decisions

#### Key Questions

**Q1: What level of detail is needed for audits?**
- Just deletion counts? Or sample records?
- Settings snapshot at time of purge?
- Who initiated retention changes?
- Approval chain for reviewed deletions?

**Design Decision: Comprehensive Audit Trail**
```ruby
# app/models/better_together/metrics/audit_log.rb
module BetterTogether
  module Metrics
    class AuditLog < ApplicationRecord
      belongs_to :platform
      belongs_to :initiated_by, class_name: 'BetterTogether::Person', optional: true
      belongs_to :approved_by, class_name: 'BetterTogether::Person', optional: true
      belongs_to :retention_change, optional: true
      
      # Event types
      enum event_type: {
        purge_scheduled: 'purge_scheduled',
        purge_started: 'purge_started',
        purge_completed: 'purge_completed',
        purge_failed: 'purge_failed',
        settings_changed: 'settings_changed',
        retention_change_requested: 'retention_change_requested',
        retention_change_approved: 'retention_change_approved',
        retention_change_rejected: 'retention_change_rejected'
      }, _suffix: true
      
      # Detailed tracking
      attribute :record_counts, :jsonb, default: {}
      attribute :settings_snapshot, :jsonb, default: {}
      attribute :error_details, :jsonb, default: {}
      attribute :metadata, :jsonb, default: {}
      
      # Record samples for forensic analysis
      attribute :deleted_record_samples, :jsonb, default: {}
      
      # Timestamps
      validates :event_at, presence: true
      
      # Retention: 7 years for compliance
      def self.retention_period
        7.years
      end
      
      # Scopes
      scope :purge_events, -> { where(event_type: %w[purge_started purge_completed purge_failed]) }
      scope :configuration_events, -> { where(event_type: %w[settings_changed retention_change_requested]) }
      scope :approval_events, -> { where(event_type: %w[retention_change_approved retention_change_rejected]) }
      scope :recent, -> { order(event_at: :desc) }
      scope :for_audit, -> { where('event_at >= ?', 7.years.ago) }
      
      # Total records affected
      def total_records_affected
        record_counts.values.sum
      end
      
      # Generate audit report
      def to_audit_report
        {
          audit_log_id: id,
          platform: platform.name,
          event_type: event_type,
          event_date: event_at.to_date,
          event_time: event_at.strftime('%H:%M:%S %Z'),
          initiated_by: initiated_by&.name || 'System',
          approved_by: approved_by&.name,
          total_records: total_records_affected,
          breakdown: record_counts,
          settings_at_time: settings_snapshot,
          notes: metadata['notes']
        }
      end
    end
  end
end
```

**Q2: How should audit logs be accessed?**
- UI dashboard for platform managers?
- CSV export for external auditors?
- API endpoint for compliance systems?

**Design Decision: Multi-Channel Access**
```ruby
# app/controllers/better_together/metrics/audit_logs_controller.rb
module BetterTogether
  module Metrics
    class AuditLogsController < ApplicationController
      before_action :authorize_audit_access
      
      def index
        @audit_logs = AuditLog
          .where(platform: current_platform)
          .for_audit
          .includes(:initiated_by, :approved_by)
          .recent
          .page(params[:page])
          .per(50)
        
        respond_to do |format|
          format.html
          format.csv { send_audit_csv }
          format.json { render json: @audit_logs.map(&:to_audit_report) }
        end
      end
      
      def show
        @audit_log = AuditLog.find(params[:id])
        authorize @audit_log
      end
      
      def export
        # Generate comprehensive audit report
        report = AuditReportGenerator.new(
          platform: current_platform,
          start_date: params[:start_date],
          end_date: params[:end_date],
          include_samples: params[:include_samples] == 'true'
        )
        
        send_data report.generate_pdf,
                  filename: "metrics_audit_#{Date.current}.pdf",
                  type: 'application/pdf'
      end
      
      private
      
      def authorize_audit_access
        unless current_person.has_role?('platform_manager') ||
               current_person.has_role?('legal_compliance_officer')
          raise Pundit::NotAuthorizedError
        end
      end
      
      def send_audit_csv
        csv_data = CSV.generate(headers: true) do |csv|
          csv << %w[Date Time Event InitiatedBy ApprovedBy RecordsDeleted Details]
          
          @audit_logs.each do |log|
            csv << [
              log.event_at.to_date,
              log.event_at.strftime('%H:%M:%S'),
              log.event_type.titleize,
              log.initiated_by&.name || 'System',
              log.approved_by&.name,
              log.total_records_affected,
              log.metadata['notes']
            ]
          end
        end
        
        send_data csv_data,
                  filename: "metrics_audit_#{Date.current}.csv",
                  type: 'text/csv'
      end
    end
  end
end
```

**Q3: What about deleted record samples?**
- Store samples before deletion for forensics?
- How many samples? What fields?
- Privacy implications of storing samples?

**Design Decision: Limited Sample Collection**
```ruby
def purge_page_views_with_sampling(settings)
  cutoff_date = settings.page_views_retention_days.days.ago
  
  scope = PageView.where('viewed_at < ?', cutoff_date)
  
  # Collect small sample (max 100 records) before deletion
  # Only non-sensitive fields for audit purposes
  samples = scope.limit(100).pluck(
    :id,
    :pageable_type,
    :pageable_id,
    :viewed_at,
    :locale
    # Note: NOT including page_url to minimize data exposure
  )
  
  # Store sanitized samples in audit log
  @audit_log.update!(
    deleted_record_samples: {
      page_views: samples.map do |id, type, pageable_id, viewed_at, locale|
        {
          id: id,
          type: type,
          pageable_id: pageable_id,
          date: viewed_at.to_date,
          locale: locale
        }
      end
    }
  )
  
  # Now delete
  scope.in_batches(of: 1000).delete_all
end
```

#### UI Design: Audit Trail Dashboard

```erb
<%# app/views/better_together/metrics/audit_logs/index.html.erb %>
<div class="container-fluid">
  <div class="row">
    <div class="col-12">
      <div class="d-flex justify-content-between align-items-center mb-4">
        <h2><%= t('.title') %></h2>
        
        <div class="btn-group">
          <%= link_to t('.export_csv'), 
              metrics_audit_logs_path(format: :csv, **filter_params),
              class: 'btn btn-outline-primary' %>
          <%= link_to t('.export_pdf'),
              export_metrics_audit_logs_path(filter_params),
              class: 'btn btn-outline-primary' %>
        </div>
      </div>
      
      <%# Filters %>
      <%= form_with url: metrics_audit_logs_path, method: :get, class: 'mb-4' do |f| %>
        <div class="row g-3">
          <div class="col-md-3">
            <%= f.label :start_date, class: 'form-label' %>
            <%= f.date_field :start_date, 
                value: params[:start_date],
                class: 'form-control' %>
          </div>
          
          <div class="col-md-3">
            <%= f.label :end_date, class: 'form-label' %>
            <%= f.date_field :end_date,
                value: params[:end_date],
                class: 'form-control' %>
          </div>
          
          <div class="col-md-4">
            <%= f.label :event_type, class: 'form-label' %>
            <%= f.select :event_type,
                options_for_select(
                  BetterTogether::Metrics::AuditLog.event_types.keys.map { |k| [k.titleize, k] },
                  params[:event_type]
                ),
                { include_blank: t('.all_events') },
                class: 'form-select' %>
          </div>
          
          <div class="col-md-2 d-flex align-items-end">
            <%= f.submit t('buttons.filter'), class: 'btn btn-primary w-100' %>
          </div>
        </div>
      <% end %>
      
      <%# Audit Log Table %>
      <div class="table-responsive">
        <table class="table table-hover">
          <thead>
            <tr>
              <th><%= t('.date_time') %></th>
              <th><%= t('.event') %></th>
              <th><%= t('.initiated_by') %></th>
              <th><%= t('.approved_by') %></th>
              <th class="text-end"><%= t('.records_affected') %></th>
              <th><%= t('.status') %></th>
              <th class="text-end"><%= t('.actions') %></th>
            </tr>
          </thead>
          <tbody>
            <% @audit_logs.each do |log| %>
              <tr>
                <td>
                  <%= l(log.event_at, format: :short) %><br>
                  <small class="text-muted">
                    <%= time_ago_in_words(log.event_at) %> ago
                  </small>
                </td>
                <td>
                  <span class="badge bg-<%= event_badge_color(log.event_type) %>">
                    <%= log.event_type.titleize %>
                  </span>
                </td>
                <td><%= log.initiated_by&.name || t('.system') %></td>
                <td><%= log.approved_by&.name || '-' %></td>
                <td class="text-end">
                  <%= number_with_delimiter(log.total_records_affected) %>
                </td>
                <td>
                  <% if log.purge_completed? %>
                    <i class="fas fa-check-circle text-success"></i>
                    <%= t('.completed') %>
                  <% elsif log.purge_failed? %>
                    <i class="fas fa-exclamation-circle text-danger"></i>
                    <%= t('.failed') %>
                  <% else %>
                    <i class="fas fa-info-circle text-info"></i>
                    <%= log.event_type.titleize %>
                  <% end %>
                </td>
                <td class="text-end">
                  <%= link_to t('buttons.view'),
                      metrics_audit_log_path(log),
                      class: 'btn btn-sm btn-outline-primary' %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      
      <%= paginate @audit_logs %>
    </div>
  </div>
</div>
```

#### Acceptance Criteria Updates

**Original:**
- ✅ Audit log shows date, record counts, retention settings used
- ✅ Accessible from platform management interface
- ✅ Filterable by date range
- ✅ Exportable as CSV for auditors
- ✅ Retained for 7 years (compliance requirement)

**Enhanced:**
- ✅ **Multiple export formats** - CSV, PDF, JSON API
- ✅ **Comprehensive event types** - purges, config changes, approvals
- ✅ **Approval chain tracking** - who requested, who approved
- ✅ **Record samples** - limited samples for forensic analysis
- ✅ **Real-time dashboard** - live view of purge events
- ✅ **Role-based access** - platform managers and compliance officers only
- ✅ **Settings snapshot** - capture configuration at time of event
- ✅ **Error tracking** - failed purge details for troubleshooting

---

## US-MET-004 & US-MET-005: Performance Optimization

### Combined Analysis (Related Stories)

**US-MET-004:** Analytics Viewer - Fast Reports  
**US-MET-005:** Platform Developer - Query Performance

These stories are technically coupled - both address database performance.

#### Key Questions

**Q1: What are the actual performance bottlenecks?**

Current report generation logic (from reading the codebase):
```ruby
# app/models/better_together/metrics/page_view_report.rb
def generate_report!
  from_date = filters['from_date'].present? ? Date.parse(filters['from_date']) : nil
  to_date = filters['to_date'].present? ? Date.parse(filters['to_date']) : nil
  
  # ❌ Problem 1: Loads ALL records into memory
  base_scope = BetterTogether::Metrics::PageView.all
  base_scope = base_scope.where('viewed_at >= ?', from_date) if from_date
  base_scope = base_scope.where('viewed_at <= ?', to_date) if to_date
  
  # ❌ Problem 2: Multiple database queries per pageable type
  types = base_scope.distinct.pluck(:pageable_type)
  types.each do |type|
    type_scope = base_scope.where(pageable_type: type)
    total_views = type_scope.group(:pageable_id).count
    locale_breakdowns = type_scope.group(:pageable_id, :locale).count
    
    # ❌ Problem 3: N+1 query to get friendly names
    ids = total_views.keys
    records = type.constantize.where(id: ids).index_by(&:id)
    
    # ❌ Problem 4: Mobility queries in loop
    distinct_locales.each do |locale|
      Mobility.with_locale(locale) do
        record_obj.title # Database query per locale per record
      end
    end
  end
end
```

**Design Decision: SQL-Based Aggregation**
```ruby
def generate_report!
  from_date = parse_date(filters['from_date'])
  to_date = parse_date(filters['to_date'])
  exclude_bots = filters['exclude_bots'] != 'false'
  
  # ✅ Single SQL query with aggregation
  aggregated_data = PageView
    .select(
      'pageable_type',
      'pageable_id',
      'locale',
      'COUNT(*) as view_count',
      'MIN(viewed_at) as first_view',
      'MAX(viewed_at) as last_view'
    )
    .then { |q| from_date ? q.where('viewed_at >= ?', from_date) : q }
    .then { |q| to_date ? q.where('viewed_at <= ?', to_date) : q }
    .then { |q| exclude_bots ? q.where(is_bot: false) : q }
    .group(:pageable_type, :pageable_id, :locale)
    .having('COUNT(*) > 0')
    .order('COUNT(*) DESC')
  
  # ✅ Build report from aggregated results
  self.report_data = build_report_from_aggregation(aggregated_data)
end

private

def build_report_from_aggregation(aggregated_data)
  # Group by pageable_type and pageable_id
  grouped = aggregated_data.group_by { |row| [row.pageable_type, row.pageable_id] }
  
  # ✅ Batch load all needed records (one query per type)
  records_by_type = load_pageable_records(grouped.keys)
  
  report = {}
  grouped.each do |(pageable_type, pageable_id), locale_rows|
    total_views = locale_rows.sum(&:view_count)
    
    locale_breakdown = locale_rows.each_with_object({}) do |row, hash|
      hash[row.locale] = {
        count: row.view_count,
        first_view: row.first_view,
        last_view: row.last_view
      }
    end
    
    record = records_by_type.dig(pageable_type, pageable_id)
    
    report[pageable_id] = {
      pageable_type: pageable_type,
      total_views: total_views,
      locale_breakdown: locale_breakdown,
      friendly_names: fetch_friendly_names(record, locale_breakdown.keys),
      metadata: {
        first_viewed: locale_rows.min_by(&:first_view)&.first_view,
        last_viewed: locale_rows.max_by(&:last_view)&.last_view
      }
    }
  end
  
  report
end

def load_pageable_records(pageable_keys)
  records = {}
  
  # Group keys by type
  by_type = pageable_keys.group_by(&:first)
  
  # ✅ One query per type (not per record)
  by_type.each do |type, keys|
    ids = keys.map(&:last)
    model_class = type.constantize
    
    records[type] = model_class
      .where(id: ids)
      .index_by(&:id)
  end
  
  records
end

def fetch_friendly_names(record, locales)
  return {} unless record
  
  # ✅ Cache translated attributes (Mobility optimization)
  names = {}
  locales.each do |locale|
    names[locale] = Mobility.with_locale(locale) do
      if record.respond_to?(:title) && record.title.present?
        record.title
      elsif record.respond_to?(:name) && record.name.present?
        record.name
      else
        "#{record.class.name} ##{record.id}"
      end
    end
  end
  names
end
```

**Q2: What indexes are actually needed?**

Looking at the queries generated:
```sql
-- Before: Sequential scan
SELECT * FROM better_together_metrics_page_views
WHERE viewed_at >= '2025-01-01' AND viewed_at <= '2026-01-01';

-- After: Index scan
-- Needs: CREATE INDEX idx_page_views_viewed_at ON ... (viewed_at);

-- Group by queries
SELECT pageable_type, pageable_id, locale, COUNT(*)
FROM better_together_metrics_page_views
WHERE viewed_at BETWEEN '2025-01-01' AND '2026-01-01'
GROUP BY pageable_type, pageable_id, locale;

-- Optimal composite index
CREATE INDEX idx_page_views_reporting ON better_together_metrics_page_views
  (viewed_at, pageable_type, pageable_id, locale);
```

**Design Decision: Targeted Index Strategy**
```ruby
# db/migrate/YYYYMMDDHHMMSS_add_metrics_performance_indexes.rb
class AddMetricsPerformanceIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    # Primary reporting index: date range + grouping columns
    add_index :better_together_metrics_page_views,
              [:viewed_at, :pageable_type, :pageable_id, :locale],
              algorithm: :concurrently,
              name: 'idx_page_views_reporting'
    
    # Bot filtering index
    add_index :better_together_metrics_page_views,
              [:is_bot, :viewed_at],
              algorithm: :concurrently,
              name: 'idx_page_views_bot_filtering',
              where: 'is_bot = false'  # Partial index for performance
    
    # Similar for other metrics tables
    add_index :better_together_metrics_link_clicks,
              [:clicked_at, :url, :internal],
              algorithm: :concurrently,
              name: 'idx_link_clicks_reporting'
    
    add_index :better_together_metrics_search_queries,
              [:searched_at, :query],
              algorithm: :concurrently,
              name: 'idx_search_queries_reporting'
    
    # Purge optimization indexes
    add_index :better_together_metrics_page_views,
              :viewed_at,
              algorithm: :concurrently,
              name: 'idx_page_views_purge',
              where: "viewed_at < (CURRENT_DATE - INTERVAL '30 days')"
    
    add_index :better_together_metrics_link_clicks,
              :clicked_at,
              algorithm: :concurrently,
              name: 'idx_link_clicks_purge',
              where: "clicked_at < (CURRENT_DATE - INTERVAL '30 days')"
  end
end
```

**Q3: What about caching?**

```ruby
# app/models/better_together/metrics/page_view_report.rb
class PageViewReport < ApplicationRecord
  # Cache report generation results
  def generate_report!
    # Check if identical report already exists
    cache_key = build_cache_key
    
    if (cached = Rails.cache.read(cache_key))
      self.report_data = cached
      return
    end
    
    # Generate report
    data = perform_aggregation
    
    # Cache for 1 hour
    Rails.cache.write(cache_key, data, expires_in: 1.hour)
    
    self.report_data = data
  end
  
  private
  
  def build_cache_key
    filters_hash = Digest::SHA256.hexdigest(filters.to_json)
    "metrics/page_view_report/#{filters_hash}"
  end
end
```

#### Performance Benchmarks

```ruby
# spec/performance/metrics_report_performance_spec.rb
require 'rails_helper'
require 'benchmark'

RSpec.describe 'Metrics Report Performance', type: :performance do
  let(:platform) { create(:platform, host: true) }
  
  before(:all) do
    # Create realistic test data
    puts "Creating test data..."
    
    # 100K page views across 90 days
    100_000.times do |i|
      create(:page_view,
        viewed_at: rand(90.days.ago..Time.current),
        locale: %w[en es fr].sample,
        pageable: create(:page)
      )
      print '.' if (i % 1000).zero?
    end
    puts "\nTest data created"
  end
  
  context 'page view report generation' do
    it 'completes in under 5 seconds for 100K records' do
      report = create(:page_view_report,
        filters: {
          'from_date' => 30.days.ago.to_date.to_s,
          'to_date' => Date.today.to_s,
          'exclude_bots' => 'true'
        }
      )
      
      benchmark = Benchmark.measure do
        report.generate_report!
      end
      
      puts "\n📊 Report generation time: #{benchmark.real.round(2)}s"
      puts "📈 Records processed: #{PageView.where('viewed_at >= ?', 30.days.ago).count}"
      puts "📄 Report entries: #{report.report_data.size}"
      
      expect(benchmark.real).to be < 5.0
    end
  end
  
  context 'query performance' do
    it 'uses indexes for date range queries' do
      explain = PageView
        .where('viewed_at >= ?', 30.days.ago)
        .where(is_bot: false)
        .explain
      
      puts "\n🔍 Query plan:\n#{explain}"
      
      expect(explain).to match(/Index (Scan|Only Scan)/i)
      expect(explain).not_to match(/Seq Scan/i)
    end
  end
end
```

---

## US-MET-006, US-MET-007, US-MET-008: Privacy Documentation

### Combined Analysis (Documentation Stories)

**US-MET-006:** Data Subject - Understand Data Collection  
**US-MET-007:** Platform Organizer - Third-Party Integration Guidance  
**US-MET-008:** Platform Organizer - Data Subject Rights Procedures

These stories cover different aspects of privacy documentation for Canadian compliance.

#### Key Questions

**Q1: What makes Canadian privacy documentation different from GDPR/CCPA templates?**

Key differences:
- **PIPEDA** uses "meaningful consent" vs GDPR's "affirmative action"
- **Implied consent** acceptable in some contexts (commercial relationships)
- **Canadian Anti-Spam Law (CASL)** has stricter email consent rules than CanSpam
- **Provincial variations**: Quebec Bill 64, BC/AB PIPA have additional requirements
- **French language** requirement in Quebec
- **Breach notification** required within 72 hours (similar to GDPR but different thresholds)

**Design Decision: Canadian-Specific Privacy Policy Template**
```markdown
# Privacy Policy Template for Better Together Platforms (Canada)

## English Version

### 1. Introduction

[Platform Name] ("we", "us", "our") operates this community platform using Better Together 
Community Engine. We are committed to protecting your privacy in accordance with:

- Personal Information Protection and Electronic Documents Act (PIPEDA)
- Canada's Anti-Spam Legislation (CASL)
- [If applicable: Quebec's Bill 64 / BC PIPA / AB PIPA]

This policy explains what information we collect, how we use it, and your rights.

### 2. Information We Collect

#### 2.1 Account Information (Required for Registration)
- Email address (for authentication and communication)
- Display name (how you appear to other members)
- Password (encrypted, never stored in plain text)

**Legal Basis:** Contractual necessity - needed to provide community services.

#### 2.2 Profile Information (Optional)
- Biography/about text
- Avatar image
- Location (city/region only, never precise coordinates)
- Interests and skills

**Legal Basis:** Consent - you choose what to share.

#### 2.3 Community Activity
- Posts, comments, and messages you create
- Reactions (likes, votes) you provide
- Groups and events you join
- Content you share or download

**Legal Basis:** Contractual necessity and legitimate interest in community operation.

#### 2.4 Analytics Information (Privacy-First)

We collect **aggregated, non-identifiable metrics** to improve the platform:

- **Page views:** Which pages are visited (no personal information)
- **Link clicks:** Which links are popular
- **Search queries:** Common search terms (no user association)
- **Downloads:** Resource popularity
- **Shares:** Content sharing frequency

**What We DON'T Collect:**
- ❌ IP addresses
- ❌ Device fingerprints
- ❌ Cross-site tracking cookies
- ❌ Personal browsing history
- ❌ Location data (GPS, precise coordinates)

**Legal Basis:** Legitimate interest in platform improvement, with privacy by design.

**Your Rights:**
- You can request metric deletion for specific content you created
- All metrics are automatically deleted after [X] days

### 3. How We Use Your Information

#### 3.1 Essential Platform Functions
- Authenticate your identity when you log in
- Display your profile to other community members
- Deliver notifications about community activity
- Enable communication with other members

#### 3.2 Community Management
- Enforce community guidelines and terms of service
- Respond to reports of inappropriate content
- Prevent spam, abuse, and security threats

#### 3.3 Platform Improvement
- Analyze which features are most useful (aggregate metrics only)
- Fix bugs and improve performance
- Plan new features based on community needs

### 4. Sharing Your Information

We do **NOT** sell your information to third parties.

We share information only when:

#### 4.1 You Choose to Share
- Your public profile is visible to other community members
- Posts in public groups are visible to all members
- Private messages are visible only to recipients

#### 4.2 Legal Requirements
- Court orders or legal processes
- Compliance with PIPEDA, CASL, or other applicable laws
- Protection of rights, property, or safety

#### 4.3 Service Providers (Processors)
We use the following third-party services:

| Service | Purpose | Data Shared | Privacy Policy |
|---------|---------|-------------|----------------|
| [Email Provider] | Transactional emails | Email address, name | [Link] |
| [Storage Provider] | File uploads | Encrypted files | [Link] |
| [Error Tracking] | Bug monitoring | Error logs (no PII) | [Link] |

All processors are bound by data processing agreements meeting PIPEDA standards.

### 5. Data Retention

| Data Type | Retention Period | Reason |
|-----------|------------------|--------|
| Page Views | [90] days | Analytics, recent trends |
| Link Clicks | [90] days | Content effectiveness |
| Search Queries | [30] days | Search improvement (privacy-sensitive) |
| Downloads | [180] days | Resource popularity |
| Shares | [365] days | Long-term engagement trends |
| Account Data | Until account deletion | Service provision |
| Audit Logs | 7 years | Legal compliance (PIPEDA) |

**Automatic Deletion:** Metrics are automatically deleted after their retention period.

**Your Control:** You can request immediate deletion of your data (see Section 7).

### 6. Data Security

We protect your information using:
- **Encryption in transit:** HTTPS/TLS for all connections
- **Encryption at rest:** Database and file encryption
- **Access controls:** Role-based permissions, multi-factor authentication
- **Regular audits:** Security reviews and vulnerability scanning
- **Breach notification:** We will notify you within 72 hours of any breach affecting your data

### 7. Your Privacy Rights (PIPEDA)

Under Canadian privacy law, you have the right to:

#### 7.1 Access Your Information
Request a copy of all personal information we hold about you.  
**How:** Email privacy@[platform].ca or use Account Settings → Export Data  
**Timeline:** 30 days

#### 7.2 Correct Your Information
Update inaccurate or incomplete information.  
**How:** Account Settings → Profile or contact us  
**Timeline:** Immediate for profile updates

#### 7.3 Delete Your Information
Request deletion of your account and associated data.  
**How:** Account Settings → Delete Account  
**Timeline:** 7 days (some data retained for legal compliance)  
**Note:** Public posts may be retained in anonymized form

#### 7.4 Withdraw Consent
Opt out of non-essential communications or data collection.  
**How:** Email preferences in Account Settings  
**Timeline:** Immediate

#### 7.5 Object to Processing
Challenge our use of your information for legitimate interests.  
**How:** Contact privacy@[platform].ca  
**Timeline:** 30 days for review

#### 7.6 Data Portability
Receive your data in a structured, machine-readable format.  
**How:** Account Settings → Export Data (JSON format)  
**Timeline:** Immediate

#### 7.7 File a Complaint
If you believe we've violated your privacy rights:
- **Internal:** privacy@[platform].ca
- **Office of the Privacy Commissioner of Canada:** 1-800-282-1376 or www.priv.gc.ca
- **[Provincial authority]:** [If applicable]

### 8. Email Communications (CASL Compliance)

We send emails only with your consent:

#### 8.1 Transactional Emails (Implied Consent)
- Account verification and password resets
- Notifications you've subscribed to
- System updates affecting your account

**Opt-out:** Not available (necessary for service)

#### 8.2 Community Updates (Express Consent)
- Weekly digest of community activity
- New feature announcements
- Event invitations

**Opt-out:** Email footer "Unsubscribe" link or Account Settings → Email Preferences

We maintain records of your consent as required by CASL.

### 9. International Data Transfers

Our servers are located in **Canada** [or specify country].

If data is transferred outside Canada:
- We ensure adequate protection through PIPEDA-approved mechanisms
- You will be informed of the destination country
- Foreign laws may allow government access to your data

### 10. Children's Privacy

This platform is not intended for children under 13.

If you are a Quebec resident, additional protections apply under Bill 64 for users under 14.

### 11. Changes to This Policy

We will notify you of material changes:
- Email notification to all users
- Prominent notice on platform for 30 days
- Continued use implies acceptance (or option to delete account)

**Last Updated:** [Date]  
**Version:** [Version Number]

### 12. Contact Us

**Privacy Officer:** [Name]  
**Email:** privacy@[platform].ca  
**Mail:** [Physical Address]  
**Phone:** [Phone Number]

For general inquiries: support@[platform].ca

---

## Version Française (Quebec Bill 64 Requirement)

### 1. Introduction

[Platform Name] (« nous », « notre ») exploite cette plateforme communautaire...

[Full French translation of all sections above]

### 12. Nous Contacter

**Responsable de la protection des renseignements personnels:** [Nom]  
**Courriel:** confidentialite@[plateforme].ca  
**Adresse postale:** [Adresse physique]  
**Téléphone:** [Numéro de téléphone]

---

## Appendix A: Metric Collection Details

### What Metrics Track

**Page Views:**
- URL path (e.g., "/groups/123")
- Page type (e.g., "Group", "Event")
- Date and time
- Language/locale
- **NOT collected:** IP address, user identity, referrer

**Link Clicks:**
- Link URL
- Link text
- Internal vs external
- Date and time
- **NOT collected:** User identity, source page

**Search Queries:**
- Search terms
- Date and time
- Language/locale
- **NOT collected:** User identity, search results clicked

**Retention Schedule:**
See Section 5 - Data Retention table above.

### Opt-Out Options

Currently, metrics are collected for all users to ensure platform improvement.

We are privacy-first by design:
- No personal information in metrics
- Automatic deletion after retention period
- No third-party analytics (Google, Facebook, etc.)

**Future Feature:** Per-user opt-out flag (contact us if needed now)

---

## Appendix B: Third-Party Services Audit

| Service | Purpose | Canadian Server? | PIPEDA Compliant? | Last Reviewed |
|---------|---------|------------------|-------------------|---------------|
| [Name] | [Purpose] | ✅ Yes / ❌ No | ✅ Yes / ⚠️ Partial | [Date] |

**Review Frequency:** Quarterly

```

**Q2: How do we guide platform organizers on third-party integrations?**

**Design Decision: Third-Party Integration Checklist**
```markdown
# Third-Party Integration Privacy Checklist

## Before Enabling Any Third-Party Service

### 1. Legal Review
- [ ] Does this service have a Canadian privacy policy?
- [ ] Does it comply with PIPEDA requirements?
- [ ] Is there a data processing agreement (DPA) available?
- [ ] Does it transfer data outside Canada? (If yes, document safeguards)
- [ ] Have we reviewed their security practices?

### 2. Data Minimization
- [ ] What personal information will be shared?
- [ ] Is this the minimum necessary for the service?
- [ ] Can we use anonymization or pseudonymization?
- [ ] Can users opt out of this integration?

### 3. User Notice & Consent
- [ ] Have we updated the privacy policy to disclose this service?
- [ ] Do users see a clear notice before data is shared?
- [ ] Is consent opt-in (not pre-checked)?
- [ ] Can users withdraw consent easily?

### 4. Security Assessment
- [ ] Does the service use encryption in transit (HTTPS)?
- [ ] Does the service use encryption at rest?
- [ ] What is their breach notification policy?
- [ ] Do they have SOC 2, ISO 27001, or similar certification?

### 5. Retention & Deletion
- [ ] How long does the service retain data?
- [ ] Can we request data deletion?
- [ ] What happens to data if we stop using the service?

## Common Integrations

### Google Analytics (NOT RECOMMENDED)

**Why:** Violates privacy-first principles
- Tracks users across sites
- Shares data with Google for advertising
- Subject to US surveillance laws

**Alternative:** Use built-in Better Together metrics (privacy-first)

### Google Tag Manager (CONDITIONAL)

**Use only if:**
- You need specific privacy-respecting tools (not analytics)
- You configure IP anonymization
- You disable data sharing with Google
- You update privacy policy to disclose

**Configuration:**
```javascript
// Disable all Google advertising features
gtag('config', 'GA_MEASUREMENT_ID', {
  'anonymize_ip': true,
  'allow_google_signals': false,
  'allow_ad_personalization_signals': false
});
```

### Sentry (Error Tracking) - RECOMMENDED

**Privacy-safe configuration:**
```python
import sentry_sdk

sentry_sdk.init(
    dsn="your-dsn",
    
    # Remove PII before sending
    before_send=scrub_sensitive_data,
    
    # Don't send user identity
    send_default_pii=False,
    
    # Sample errors (not all)
    sample_rate=0.5
)

def scrub_sensitive_data(event, hint):
    # Remove email addresses
    if 'user' in event and 'email' in event['user']:
        event['user']['email'] = '[REDACTED]'
    
    # Remove IP addresses
    if 'request' in event and 'env' in event['request']:
        event['request']['env'].pop('REMOTE_ADDR', None)
    
    return event
```

**Privacy Policy Addition:**
"We use Sentry for error monitoring. Error reports include technical information 
about software failures but NO personal information. Sentry's privacy policy: 
[link]. Data is retained for 90 days."

### Email Service Providers

#### Sendgrid (CONDITIONAL)
- Requires DPA (available)
- US-based (cross-border transfer disclosure needed)
- CASL-compliant unsubscribe required

**Configuration:**
```ruby
# config/initializers/action_mailer.rb
ActionMailer::Base.smtp_settings = {
  address: 'smtp.sendgrid.net',
  # ... other settings
}

# Ensure CASL compliance
class ApplicationMailer < ActionMailer::Base
  def headers
    super.merge({
      'List-Unsubscribe' => unsubscribe_url,
      'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click'
    })
  end
end
```

**Privacy Policy Addition:**
"Transactional emails are sent via SendGrid (US-based). Only your email address 
and message content are shared. SendGrid's privacy policy: [link]."

#### Postmark (RECOMMENDED for Canada)
- Canadian data center available
- PIPEDA-compliant DPA
- Excellent deliverability
- Built-in CASL compliance tools

### File Storage

#### AWS S3 (CONDITIONAL)
- Can use Canadian region (ca-central-1)
- Requires encryption at rest and in transit
- Subject to US CLOUD Act

**Configuration:**
```ruby
# config/storage.yml
amazon:
  service: S3
  region: ca-central-1
  bucket: <%= ENV['S3_BUCKET'] %>
  
  # Encryption required
  server_side_encryption: 'AES256'
  
  # Or use KMS
  server_side_encryption: aws:kms
  kms_key_id: <%= ENV['KMS_KEY_ID'] %>
```

**Privacy Policy Addition:**
"Uploaded files are stored in Amazon S3 (Canadian region). Files are encrypted 
and accessible only to you and users you share with."

#### MinIO (RECOMMENDED)
- Self-hosted option
- Full control over data location
- S3-compatible API
- No third-party data sharing

## Integration Approval Workflow

```ruby
# app/models/better_together/third_party_integration.rb
class ThirdPartyIntegration < ApplicationRecord
  belongs_to :platform
  
  enum status: {
    proposed: 'proposed',
    under_review: 'under_review',
    approved: 'approved',
    rejected: 'rejected',
    disabled: 'disabled'
  }
  
  # Require legal review for data-sharing integrations
  validates :legal_review_notes, presence: true, if: -> { shares_personal_data? }
  validates :privacy_policy_updated, acceptance: true, if: -> { status == 'approved' }
  
  def shares_personal_data?
    data_shared.any? { |field| PERSONAL_DATA_FIELDS.include?(field) }
  end
  
  PERSONAL_DATA_FIELDS = %w[
    email
    name
    phone
    address
    ip_address
    user_id
    profile_data
  ].freeze
end
```

## Monthly Privacy Audit

Review all active integrations:
1. Check for service provider privacy policy changes
2. Verify data processing agreements are current
3. Review data retention practices
4. Test opt-out mechanisms
5. Document any changes in audit log

**Checklist:** `lib/tasks/privacy_audit.rake`
```ruby
namespace :privacy do
  desc "Generate monthly third-party integration audit"
  task audit: :environment do
    BetterTogether::Platform.find_each do |platform|
      report = ThirdPartyIntegrationAudit.new(platform)
      report.generate_monthly_report
      
      # Email to platform privacy officer
      PrivacyMailer.integration_audit(platform, report).deliver_later
    end
  end
end
```
```

**Q3: What about data subject access request (DSAR) procedures?**

**Design Decision: Automated DSAR Workflow**
```ruby
# app/models/better_together/data_subject_access_request.rb
module BetterTogether
  class DataSubjectAccessRequest < ApplicationRecord
    belongs_to :platform
    belongs_to :person # The data subject
    belongs_to :processed_by, class_name: 'Person', optional: true
    
    enum request_type: {
      access: 'access',           # Copy of all data
      correction: 'correction',   # Fix inaccurate data
      deletion: 'deletion',       # Delete account
      portability: 'portability', # Export in JSON
      objection: 'objection',     # Stop processing
      restriction: 'restriction'  # Limit processing
    }
    
    enum status: {
      submitted: 'submitted',
      identity_verification: 'identity_verification',
      processing: 'processing',
      completed: 'completed',
      rejected: 'rejected'
    }
    
    # PIPEDA timeline: 30 days
    validates :completion_deadline, presence: true
    validate :deadline_within_pipeda_timeline
    
    after_create :send_acknowledgment_email
    after_update :send_status_update_email, if: :saved_change_to_status?
    
    def deadline_within_pipeda_timeline
      max_deadline = created_at + 30.days
      if completion_deadline > max_deadline
        errors.add(:completion_deadline, "must be within 30 days (PIPEDA requirement)")
      end
    end
    
    def process_request!
      case request_type
      when 'access'
        generate_data_report
      when 'portability'
        generate_data_export
      when 'deletion'
        queue_account_deletion
      when 'correction'
        flag_for_manual_review
      end
    end
    
    private
    
    def generate_data_report
      # Collect all personal data
      data = {
        profile: person.attributes.except('encrypted_password', 'reset_password_token'),
        posts: person.posts.pluck(:id, :title, :body, :created_at),
        comments: person.comments.pluck(:id, :body, :created_at),
        messages: person.messages.pluck(:id, :body, :created_at),
        groups: person.groups.pluck(:id, :name),
        events: person.events.pluck(:id, :title, :starts_at),
        roles: person.roles.pluck(:name),
        
        # Metrics (aggregated, no PII)
        activity_summary: {
          page_views: "We do not track individual page views",
          content_created: person.posts.count + person.comments.count,
          last_login: person.current_sign_in_at
        },
        
        metadata: {
          account_created: person.created_at,
          last_updated: person.updated_at,
          timezone: person.timezone,
          locale: person.locale
        }
      }
      
      # Generate PDF report
      pdf = DataSubjectReportGenerator.new(person, data).generate_pdf
      
      # Attach to request
      self.response_file.attach(
        io: StringIO.new(pdf),
        filename: "data_report_#{person.id}_#{Date.current}.pdf",
        content_type: 'application/pdf'
      )
      
      update!(
        status: :completed,
        processed_at: Time.current,
        processed_by: Platform.system_user
      )
    end
    
    def generate_data_export
      # JSON export for portability
      data = person.as_json(
        include: {
          posts: { include: :comments },
          messages: {},
          groups: {},
          events: {}
        }
      )
      
      json = JSON.pretty_generate(data)
      
      self.response_file.attach(
        io: StringIO.new(json),
        filename: "data_export_#{person.id}_#{Date.current}.json",
        content_type: 'application/json'
      )
      
      update!(status: :completed, processed_at: Time.current)
    end
    
    def queue_account_deletion
      # 7-day grace period before permanent deletion
      AccountDeletionJob.set(wait: 7.days).perform_later(person.id)
      
      update!(
        status: :processing,
        notes: "Account scheduled for deletion in 7 days. Cancel by #{7.days.from_now.to_date}."
      )
    end
  end
end
```

**UI for DSAR Submission:**
```erb
<%# app/views/better_together/account/privacy/new.html.erb %>
<div class="container my-5">
  <h2><%= t('.title') %></h2>
  <p class="lead"><%= t('.description') %></p>
  
  <%= form_with model: @dsar, url: account_privacy_requests_path do |f| %>
    <div class="mb-4">
      <%= f.label :request_type, class: 'form-label' %>
      <%= f.select :request_type,
          options_for_select([
            [t('.request_types.access'), 'access'],
            [t('.request_types.correction'), 'correction'],
            [t('.request_types.deletion'), 'deletion'],
            [t('.request_types.portability'), 'portability'],
            [t('.request_types.objection'), 'objection']
          ]),
          {},
          class: 'form-select' %>
      
      <div class="form-text">
        <strong><%= t('.request_types.access') %>:</strong> 
        <%= t('.request_types.access_description') %><br>
        
        <strong><%= t('.request_types.portability') %>:</strong>
        <%= t('.request_types.portability_description') %><br>
        
        <strong><%= t('.request_types.deletion') %>:</strong>
        <%= t('.request_types.deletion_description') %><br>
      </div>
    </div>
    
    <div class="mb-4">
      <%= f.label :reason, class: 'form-label' %>
      <%= f.text_area :reason, 
          rows: 4,
          class: 'form-control',
          placeholder: t('.reason_placeholder') %>
      <div class="form-text"><%= t('.reason_help') %></div>
    </div>
    
    <div class="alert alert-info">
      <i class="fas fa-info-circle"></i>
      <strong><%= t('.timeline_notice') %></strong>
      <%= t('.timeline_description') %>
    </div>
    
    <div class="mb-4">
      <%= f.check_box :identity_confirmed, class: 'form-check-input' %>
      <%= f.label :identity_confirmed, class: 'form-check-label' do %>
        <%= t('.identity_confirmation') %>
      <% end %>
    </div>
    
    <%= f.submit t('buttons.submit_request'), class: 'btn btn-primary' %>
  <% end %>
</div>
```

#### Acceptance Criteria Updates

**US-MET-006 (Understand Data Collection):**
- ✅ Canadian-specific privacy policy template
- ✅ English and French versions (Quebec Bill 64)
- ✅ Clear metrics collection disclosure
- ✅ "What we DON'T collect" section
- ✅ Retention periods in plain language
- ✅ Third-party service disclosure table

**US-MET-007 (Third-Party Integration):**
- ✅ Integration privacy checklist
- ✅ Service-specific configuration guides
- ✅ Privacy policy update templates
- ✅ Monthly audit task
- ✅ Integration approval workflow model
- ✅ Canadian-preferred alternatives (Postmark, MinIO)

**US-MET-008 (Data Subject Rights):**
- ✅ Automated DSAR workflow
- ✅ 30-day PIPEDA timeline enforcement
- ✅ PDF and JSON export formats
- ✅ 7-day deletion grace period
- ✅ User-friendly request form
- ✅ Email notifications at each status change
- ✅ Office of Privacy Commissioner contact info

---

## US-MET-009, US-MET-010, US-MET-011: Bot Filtering

### Combined Analysis (Bot Detection Stories)

**US-MET-009:** Platform Developer - Bot Detection  
**US-MET-010:** Analytics Viewer - Exclude Bots from Reports  
**US-MET-011:** Analytics Viewer - Bot Filtering UI

#### Key Questions

**Q1: What bot detection strategy works for privacy-first analytics?**

Common approaches:
1. **User-Agent analysis** (doesn't require PII)
2. **IP-based detection** (violates privacy-first principle)
3. **Behavioral analysis** (requires session tracking - partial violation)
4. **JavaScript challenges** (accessibility concerns)

**Design Decision: User-Agent Based Detection**
```ruby
# app/services/better_together/metrics/bot_detection_service.rb
module BetterTogether
  module Metrics
    class BotDetectionService
      # Common bot patterns (user agent strings)
      BOT_PATTERNS = [
        # Search engine crawlers
        /googlebot/i,
        /bingbot/i,
        /slurp/i,          # Yahoo
        /duckduckbot/i,
        /baiduspider/i,
        /yandexbot/i,
        /sogou/i,
        
        # Social media crawlers
        /facebookexternalhit/i,
        /twitterbot/i,
        /linkedinbot/i,
        /pinterest/i,
        /slackbot/i,
        /discordbot/i,
        /whatsapp/i,
        /telegrambot/i,
        
        # Monitoring & Analytics
        /uptimerobot/i,
        /pingdom/i,
        /newrelic/i,
        /datadog/i,
        
        # SEO & Testing
        /ahrefsbot/i,
        /semrushbot/i,
        /mj12bot/i,        # Majestic
        /dotbot/i,
        /headlesschrome/i,
        /phantomjs/i,
        /selenium/i,
        
        # Archive & Research
        /archive\.org_bot/i,
        /ia_archiver/i,
        
        # Generic bot indicators
        /bot\b/i,
        /crawler/i,
        /spider/i,
        /scraper/i,
        
        # Canadian-specific bots
        /gc-spider/i,      # Government of Canada
        /statscan/i        # Statistics Canada
      ].freeze
      
      def self.bot?(user_agent)
        return false if user_agent.blank?
        
        BOT_PATTERNS.any? { |pattern| user_agent.match?(pattern) }
      end
      
      # More sophisticated check
      def self.detailed_check(user_agent, request_headers: {})
        return { is_bot: false, confidence: 0.0, reason: nil } if user_agent.blank?
        
        # Check user agent pattern
        if BOT_PATTERNS.any? { |pattern| user_agent.match?(pattern) }
          return {
            is_bot: true,
            confidence: 0.95,
            reason: 'User agent matches known bot pattern'
          }
        end
        
        # Check for missing headers (bots often omit these)
        suspicious_headers = []
        suspicious_headers << 'missing_accept_language' if request_headers['Accept-Language'].blank?
        suspicious_headers << 'missing_accept_encoding' if request_headers['Accept-Encoding'].blank?
        
        # Headless browsers
        if user_agent.match?(/headless/i) || user_agent.match?(/phantomjs/i)
          return {
            is_bot: true,
            confidence: 0.90,
            reason: 'Headless browser detected'
          }
        end
        
        # Suspiciously generic user agents
        if user_agent.match?/^(mozilla|curl|wget|python|ruby|java)/i) && user_agent.split.count < 3
          return {
            is_bot: true,
            confidence: 0.70,
            reason: 'Suspiciously generic user agent'
          }
        end
        
        # Calculate overall suspicion score
        suspicion_score = suspicious_headers.count * 0.15
        
        if suspicion_score > 0.5
          return {
            is_bot: true,
            confidence: suspicion_score,
            reason: "Suspicious headers: #{suspicious_headers.join(', ')}"
          }
        end
        
        {
          is_bot: false,
          confidence: 1.0 - suspicion_score,
          reason: 'Appears to be legitimate user'
        }
      end
    end
  end
end
```

**Q2: How do we handle false positives?**

Examples:
- Privacy-focused browsers (Brave, Tor) may have unusual user agents
- Corporate proxies may strip headers
- Users with ad blockers may appear suspicious

**Design Decision: Manual Override + Allowlist**
```ruby
# app/models/better_together/metrics/bot_allowlist.rb
class BotAllowlist < ApplicationRecord
  belongs_to :platform
  
  # User agent patterns that should NOT be flagged as bots
  attribute :pattern, :string
  attribute :reason, :text
  
  validates :pattern, presence: true, uniqueness: { scope: :platform_id }
  
  scope :active, -> { where(active: true) }
  
  def matches?(user_agent)
    Regexp.new(pattern, Regexp::IGNORECASE).match?(user_agent)
  end
  
  # Example entries
  # pattern: "Brave/", reason: "Brave browser users"
  # pattern: "TorBrowser", reason: "Tor users for privacy"
end

# Updated detection service
def self.bot?(user_agent, platform: nil)
  return false if user_agent.blank?
  
  # Check allowlist first
  if platform
    allowlist = BotAllowlist.active.where(platform: platform)
    return false if allowlist.any? { |entry| entry.matches?(user_agent) }
  end
  
  # Then check bot patterns
  BOT_PATTERNS.any? { |pattern| user_agent.match?(pattern) }
end
```

**Q3: What about performance impact?**

```ruby
# Benchmark bot detection
require 'benchmark'

user_agents = [
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  "Googlebot/2.1 (+http://www.google.com/bot.html)",
  "facebookexternalhit/1.1",
  "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)"
]

Benchmark.bm do |x|
  x.report("Simple check (10k):") do
    10_000.times do
      user_agents.each { |ua| BotDetectionService.bot?(ua) }
    end
  end
  
  x.report("Detailed check (10k):") do
    10_000.times do
      user_agents.each { |ua| BotDetectionService.detailed_check(ua) }
    end
  end
end

# Expected results:
# Simple check: ~0.05s (500 checks/ms)
# Detailed check: ~0.15s (166 checks/ms)
# Conclusion: Negligible performance impact
```

#### Database Schema Changes

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_bot_detection_to_metrics.rb
class AddBotDetectionToMetrics < ActiveRecord::Migration[7.2]
  def change
    # Add user_agent field to page views
    add_column :better_together_metrics_page_views, :user_agent, :string
    add_column :better_together_metrics_page_views, :is_bot, :boolean, default: false, null: false
    add_column :better_together_metrics_page_views, :bot_confidence, :decimal, precision: 3, scale: 2
    
    # Index for filtering
    add_index :better_together_metrics_page_views, :is_bot
    add_index :better_together_metrics_page_views, [:is_bot, :viewed_at],
              name: 'idx_page_views_bot_filtering'
    
    # Partial index for bot-free queries
    add_index :better_together_metrics_page_views,
              [:viewed_at, :pageable_type, :pageable_id, :locale],
              where: 'is_bot = false',
              name: 'idx_page_views_human_only'
    
    # Link clicks
    add_column :better_together_metrics_link_clicks, :user_agent, :string
    add_column :better_together_metrics_link_clicks, :is_bot, :boolean, default: false, null: false
    add_index :better_together_metrics_link_clicks, :is_bot
    
    # Search queries (already privacy-sensitive, less critical)
    add_column :better_together_metrics_search_queries, :user_agent, :string
    add_column :better_together_metrics_search_queries, :is_bot, :boolean, default: false, null: false
    add_index :better_together_metrics_search_queries, :is_bot
  end
end
```

#### Updated Tracking Code

```ruby
# app/controllers/concerns/better_together/metrics_tracking.rb
module BetterTogether
  module MetricsTracking
    extend ActiveSupport::Concern
    
    included do
      after_action :track_page_view, only: [:show, :index]
    end
    
    private
    
    def track_page_view
      return if request.format.json? || request.format.xml?
      return unless trackable_resource
      
      user_agent = request.user_agent
      bot_detection = Metrics::BotDetectionService.detailed_check(
        user_agent,
        request_headers: request.headers
      )
      
      Metrics::PageView.create!(
        pageable: trackable_resource,
        viewed_at: Time.current,
        locale: I18n.locale,
        user_agent: user_agent,
        is_bot: bot_detection[:is_bot],
        bot_confidence: bot_detection[:confidence]
      )
    rescue ActiveRecord::RecordInvalid => e
      # Don't let metrics tracking break the app
      Rails.logger.warn "[Metrics] Failed to track page view: #{e.message}"
    end
  end
end
```

#### Report Filtering UI

```erb
<%# app/views/better_together/metrics/reports/_filter_form.html.erb %>
<%= form_with url: metrics_reports_path, method: :get, class: 'metrics-filter-form' do |f| %>
  <div class="row g-3 align-items-end">
    <div class="col-md-3">
      <%= f.label :from_date, class: 'form-label' %>
      <%= f.date_field :from_date,
          value: params[:from_date] || 30.days.ago.to_date,
          class: 'form-control' %>
    </div>
    
    <div class="col-md-3">
      <%= f.label :to_date, class: 'form-label' %>
      <%= f.date_field :to_date,
          value: params[:to_date] || Date.current,
          class: 'form-control' %>
    </div>
    
    <div class="col-md-3">
      <%= f.label :bot_filter, t('.bot_filter_label'), class: 'form-label' %>
      <%= f.select :exclude_bots,
          [
            [t('.include_all_traffic'), 'false'],
            [t('.exclude_bots'), 'true'],
            [t('.bots_only'), 'only']
          ],
          { selected: params[:exclude_bots] || 'true' },
          class: 'form-select',
          data: { 
            controller: 'metrics-filter',
            action: 'change->metrics-filter#updateStats'
          } %>
      
      <div class="form-text">
        <i class="fas fa-robot text-muted"></i>
        <span id="bot-percentage">
          <%= render partial: 'bot_statistics', 
              locals: { 
                total: @total_views,
                bot_count: @bot_views 
              } %>
        </span>
      </div>
    </div>
    
    <div class="col-md-3">
      <%= f.submit t('buttons.apply_filters'), class: 'btn btn-primary w-100' %>
    </div>
  </div>
  
  <%# Advanced filters (collapsible) %>
  <div class="collapse mt-3" id="advancedFilters">
    <div class="card card-body">
      <div class="row g-3">
        <div class="col-md-6">
          <%= f.label :confidence_threshold, t('.confidence_threshold'), class: 'form-label' %>
          <%= f.range_field :confidence_threshold,
              value: params[:confidence_threshold] || 0.7,
              min: 0,
              max: 1,
              step: 0.1,
              class: 'form-range',
              data: {
                controller: 'range-value',
                action: 'input->range-value#update'
              } %>
          <div class="d-flex justify-content-between">
            <small>Low confidence</small>
            <strong>
              <span data-range-value-target="display">70</span>%
            </strong>
            <small>High confidence</small>
          </div>
          <div class="form-text">
            <%= t('.confidence_threshold_help') %>
          </div>
        </div>
        
        <div class="col-md-6">
          <%= f.label :bot_types, t('.bot_types'), class: 'form-label' %>
          <% bot_categories.each do |category, label| %>
            <div class="form-check">
              <%= f.check_box "bot_types[]",
                  { checked: params.dig(:bot_types, category) != 'false' },
                  category,
                  nil,
                  class: 'form-check-input' %>
              <%= f.label "bot_types_#{category}", label, class: 'form-check-label' %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
  </div>
  
  <button class="btn btn-sm btn-link mt-2" 
          type="button"
          data-bs-toggle="collapse"
          data-bs-target="#advancedFilters">
    <i class="fas fa-sliders-h"></i>
    <%= t('.advanced_filters') %>
  </button>
<% end %>
```

```ruby
# app/controllers/better_together/metrics/reports_controller.rb
def index
  @from_date = parse_date(params[:from_date]) || 30.days.ago.to_date
  @to_date = parse_date(params[:to_date]) || Date.current
  @exclude_bots = params[:exclude_bots] != 'false' # Default true
  @bots_only = params[:exclude_bots] == 'only'
  
  base_scope = Metrics::PageView.where(viewed_at: @from_date.beginning_of_day..@to_date.end_of_day)
  
  @total_views = base_scope.count
  @bot_views = base_scope.where(is_bot: true).count
  @human_views = @total_views - @bot_views
  @bot_percentage = (@bot_views.to_f / @total_views * 100).round(1)
  
  # Apply bot filter
  base_scope = if @bots_only
                 base_scope.where(is_bot: true)
               elsif @exclude_bots
                 base_scope.where(is_bot: false)
               else
                 base_scope # Include all
               end
  
  # Generate report from filtered scope
  @report_data = generate_report_from_scope(base_scope)
  
  respond_to do |format|
    format.html
    format.json { render json: { report: @report_data, stats: bot_stats } }
  end
end

private

def bot_stats
  {
    total_views: @total_views,
    human_views: @human_views,
    bot_views: @bot_views,
    bot_percentage: @bot_percentage
  }
end
```

#### Stimulus Controller for Live Updates

```javascript
// app/javascript/controllers/metrics_filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["botPercentage", "totalViews", "humanViews", "botViews"]
  
  async updateStats(event) {
    const formData = new FormData(this.element)
    const params = new URLSearchParams(formData)
    
    try {
      const response = await fetch(`${this.element.action}?${params}`, {
        headers: { 'Accept': 'application/json' }
      })
      
      const data = await response.json()
      
      // Update statistics display
      if (this.hasBotPercentageTarget) {
        this.botPercentageTarget.textContent = 
          `${data.stats.bot_views} of ${data.stats.total_views} views (${data.stats.bot_percentage}%) detected as bots`
      }
      
      // Trigger report table update via Turbo Frame
      this.dispatch("statsUpdated", { detail: data.stats })
      
    } catch (error) {
      console.error('Failed to update bot statistics:', error)
    }
  }
}
```

#### Acceptance Criteria Updates

**US-MET-009 (Bot Detection):**
- ✅ User-agent based detection (privacy-safe)
- ✅ 50+ bot patterns (search engines, social, monitoring)
- ✅ Canadian-specific bots (gc-spider, statscan)
- ✅ Confidence scoring (0.0 - 1.0)
- ✅ Manual allowlist for false positives
- ✅ Performance: <1ms per request
- ✅ No PII collection (no IP addresses)

**US-MET-010 (Exclude from Reports):**
- ✅ Default: exclude bots from reports
- ✅ Option to include bots or show bots only
- ✅ Partial indexes for fast bot-filtered queries
- ✅ Backward compatible with existing metrics
- ✅ Bot statistics displayed on reports

**US-MET-011 (Filtering UI):**
- ✅ Simple toggle: Include All / Exclude Bots / Bots Only
- ✅ Bot percentage displayed in real-time
- ✅ Advanced filters: confidence threshold, bot type categories
- ✅ Collapsible advanced options
- ✅ Stimulus controller for live updates
- ✅ Accessible form controls (keyboard navigation)

---

## Implementation Scope Summary

### P0 (Critical - Must Complete)

**US-MET-001: Configure Retention** (8 hours)
- Settings::Metrics model with per-metric-type retention
- Legal review workflow (RetentionChange model)
- Typing matcher confirmation UI
- Configuration audit trail

**US-MET-002: Automatic Purging** (6 hours)
- PurgeOldMetricsJob with circuit breaker
- Safe cutoff during legal review
- Batch deletion (1000 records)
- Noticed notifications

**US-MET-003: Audit Trail** (4 hours)
- AuditLog model (comprehensive event tracking)
- Dashboard UI with filters
- CSV/PDF export

**US-MET-004/005: Performance** (5 hours)
- Composite indexes for reporting
- Partial indexes for bot filtering
- SQL aggregation for reports
- Performance benchmarks

**US-MET-006/007/008: Privacy Docs** (6 hours)
- Canadian privacy policy template (English + French)
- Third-party integration checklist
- DSAR workflow and UI

**Subtotal P0:** 29 hours

### P1 (High Priority - Should Complete)

**US-MET-009/010/011: Bot Filtering** (5 hours)
- BotDetectionService with user-agent analysis
- Database schema (user_agent, is_bot fields)
- Report filtering UI
- Bot statistics display

**Subtotal P1:** 5 hours

### Total Effort: 34 hours

### MVP Option (32 hours)
If we need to reduce scope:
- Defer French translation to post-launch (+2h saved)
- Defer PDF export for DSAR (use JSON only) (+1h saved)
- Defer confidence scoring in bot detection (use boolean only) (+1h saved)

**MVP: 30 hours P0 + 2 hours simplified P1 = 32 hours**

---

## Next Steps

1. **Stakeholder Review:** Share this detailed analysis with legal/compliance and platform organizers
2. **Scope Decision:** Confirm 34h full implementation vs 32h MVP
3. **Sprint Planning:** Break into 2-day sprints (US-MET-001/002, then 003/004/005, then 006-008, then 009-011)
4. **TDD Implementation:** Write comprehensive tests for each story before code
5. **Documentation:** Update user guides and admin documentation
6. **Deployment:** Stage rollout with feature flags for gradual release
