# Phase 1: Performance & Infrastructure Optimization

## 🎯 Objective
Implement critical performance optimizations to improve dashboard load times by 70% and reduce database load.

## 📅 Timeline: 2-3 Weeks

## ✅ Implementation Checklist

### Week 1: Database Optimization

#### Database Indexes
- [ ] Add index on `mentions.keyword_id`
- [ ] Add index on `mentions.created_at`
- [ ] Add composite index on `mentions(keyword_id, created_at)`
- [ ] Add index on `leads.mention_id`
- [ ] Add index on `leads.status`
- [ ] Add index on `leads.created_at`
- [ ] Add composite index on `leads(user_id, status)`
- [ ] Add index on `integrations.user_id`
- [ ] Add index on `integrations.status`
- [ ] Add composite index on `integration_logs(integration_id, created_at)`

#### Counter Caches
- [ ] Add `mentions_count` to keywords table
- [ ] Add `leads_count` to keywords table
- [ ] Add `keywords_count` to users table
- [ ] Add `leads_count` to users table
- [ ] Add `mentions_count` to users table
- [ ] Update Keyword model with counter_cache
- [ ] Update User model with counter_cache
- [ ] Update Mention model with counter_cache
- [ ] Create rake task to backfill counter caches
- [ ] Run counter cache backfill in production

### Week 2: Query Optimization

#### Dashboard Controller Refactoring
- [ ] Create `DashboardService` class
- [ ] Move analytics calculations to service
- [ ] Implement efficient query patterns
- [ ] Add proper eager loading with includes
- [ ] Remove N+1 queries
- [ ] Optimize keyword performance queries
- [ ] Batch database operations

#### Service Objects
- [ ] Create `AnalyticsService` for complex calculations
- [ ] Create `LeadScoringService` for lead metrics
- [ ] Create `IntegrationHealthService` for integration monitoring
- [ ] Create `KeywordPerformanceService` for keyword analytics

### Week 3: Caching Implementation

#### Application-Level Caching
- [ ] Add Redis to Gemfile and configure
- [ ] Implement fragment caching for dashboard widgets
- [ ] Cache analytics calculations with TTL
- [ ] Add cache warming for frequently accessed data
- [ ] Implement cache invalidation strategies

#### Model-Level Caching
- [ ] Add memoization to expensive model methods
- [ ] Cache keyword performance metrics
- [ ] Cache user statistics
- [ ] Cache integration health scores

## 📊 Performance Metrics

### Before Optimization
- Dashboard load time: 2-5 seconds
- Database queries per request: 50-100
- Memory usage: 200-300MB per request
- CPU usage: High during peak

### Target After Optimization
- Dashboard load time: <500ms
- Database queries per request: 10-20
- Memory usage: 50-100MB per request
- CPU usage: Moderate during peak

## 🔧 Technical Implementation

### 1. Database Migration for Indexes
```ruby
class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Mentions indexes
    add_index :mentions, :keyword_id, algorithm: :concurrently
    add_index :mentions, :created_at, algorithm: :concurrently
    add_index :mentions, [:keyword_id, :created_at], algorithm: :concurrently
    
    # Leads indexes
    add_index :leads, :mention_id, algorithm: :concurrently
    add_index :leads, :status, algorithm: :concurrently
    add_index :leads, :created_at, algorithm: :concurrently
    add_index :leads, [:user_id, :status], algorithm: :concurrently
    
    # Integrations indexes
    add_index :integrations, :user_id, algorithm: :concurrently
    add_index :integrations, :status, algorithm: :concurrently
    
    # Integration logs indexes
    add_index :integration_logs, [:integration_id, :created_at], algorithm: :concurrently
  end
end
```

### 2. Counter Cache Migration
```ruby
class AddCounterCaches < ActiveRecord::Migration[8.0]
  def change
    # Keywords counter caches
    add_column :keywords, :mentions_count, :integer, default: 0, null: false
    add_column :keywords, :leads_count, :integer, default: 0, null: false
    
    # Users counter caches
    add_column :users, :keywords_count, :integer, default: 0, null: false
    add_column :users, :leads_count, :integer, default: 0, null: false
    add_column :users, :mentions_count, :integer, default: 0, null: false
    
    # Backfill counters
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE keywords SET 
            mentions_count = (SELECT COUNT(*) FROM mentions WHERE keyword_id = keywords.id),
            leads_count = (SELECT COUNT(*) FROM leads 
                          JOIN mentions ON leads.mention_id = mentions.id 
                          WHERE mentions.keyword_id = keywords.id)
        SQL
        
        execute <<-SQL
          UPDATE users SET
            keywords_count = (SELECT COUNT(*) FROM keywords WHERE user_id = users.id),
            leads_count = (SELECT COUNT(*) FROM leads WHERE user_id = users.id),
            mentions_count = (SELECT COUNT(*) FROM mentions 
                             JOIN keywords ON mentions.keyword_id = keywords.id 
                             WHERE keywords.user_id = users.id)
        SQL
      end
    end
  end
end
```

### 3. Dashboard Service Implementation
```ruby
# app/services/dashboard_service.rb
class DashboardService
  def initialize(user)
    @user = user
  end

  def call
    {
      recent_leads: recent_leads,
      keyword_performance: keyword_performance,
      integration_status: integration_status,
      analytics_data: analytics_data,
      conversion_metrics: conversion_metrics
    }
  end

  private

  def recent_leads
    @user.leads
         .includes(:mention, :keyword)
         .order(created_at: :desc)
         .limit(10)
  end

  def keyword_performance
    Rails.cache.fetch(["keyword_performance", @user.id], expires_in: 5.minutes) do
      @user.keywords
           .select('keywords.*, keywords.mentions_count, keywords.leads_count')
           .where('mentions_count > 0')
           .order('leads_count DESC')
           .limit(5)
    end
  end

  def integration_status
    @user.integrations
         .includes(:integration_logs)
         .where(status: 'active')
  end

  def analytics_data
    Rails.cache.fetch(["analytics_data", @user.id], expires_in: 10.minutes) do
      {
        leads: leads_analytics,
        conversions: conversion_analytics,
        keywords: keyword_analytics,
        integrations: integration_analytics
      }
    end
  end

  def leads_analytics
    leads = @user.leads
    {
      total: leads.count,
      this_month: leads.where(created_at: 1.month.ago..Time.current).count,
      last_month: leads.where(created_at: 2.months.ago..1.month.ago).count,
      daily: leads.group_by_day(:created_at, last: 30).count
    }
  end

  def conversion_analytics
    total_mentions = @user.mentions_count
    qualified_leads = @user.leads.where(status: 'qualified').count
    converted_leads = @user.leads.where(status: 'converted').count
    
    {
      mentions: total_mentions,
      qualified: qualified_leads,
      converted: converted_leads,
      conversion_rate: total_mentions > 0 ? (converted_leads.to_f / total_mentions * 100).round(2) : 0
    }
  end

  def keyword_analytics
    @user.keywords.map do |keyword|
      {
        name: keyword.keyword,
        mentions: keyword.mentions_count,
        leads: keyword.leads_count,
        conversion_rate: keyword.conversion_rate
      }
    end.sort_by { |k| -k[:conversion_rate] }
  end

  def integration_analytics
    @user.integrations.map do |integration|
      {
        platform: integration.provider,
        status: integration.status,
        health_score: integration.health_score,
        last_sync: integration.last_searched_at
      }
    end
  end

  def conversion_metrics
    {
      total_leads: @user.leads_count,
      new_leads_today: @user.leads.where(created_at: Date.current.all_day).count,
      conversion_rate: calculate_overall_conversion_rate,
      top_performing_keyword: top_performing_keyword
    }
  end

  def calculate_overall_conversion_rate
    return 0 if @user.mentions_count.zero?
    converted = @user.leads.where(status: 'converted').count
    (converted.to_f / @user.mentions_count * 100).round(2)
  end

  def top_performing_keyword
    @user.keywords.order(leads_count: :desc).first&.keyword
  end
end
```

### 4. Optimized Dashboard Controller
```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @dashboard_data = DashboardService.new(current_user).call
    
    respond_to do |format|
      format.html
      format.json { render json: @dashboard_data }
    end
  end

  def analytics
    render json: {
      leads: leads_analytics,
      conversions: conversion_analytics,
      keywords: keyword_analytics,
      integrations: integration_analytics
    }
  end

  def widgets
    render json: {
      recent_leads: recent_leads_widget,
      keyword_performance: keyword_performance_widget,
      integration_status: integration_status_widget,
      conversion_metrics: conversion_metrics_widget
    }
  end

  private

  def leads_analytics
    Rails.cache.fetch(["leads_analytics", current_user.id], expires_in: 5.minutes) do
      AnalyticsService.new(current_user).leads_analytics
    end
  end

  def conversion_analytics
    Rails.cache.fetch(["conversion_analytics", current_user.id], expires_in: 5.minutes) do
      AnalyticsService.new(current_user).conversion_analytics
    end
  end

  def keyword_analytics
    Rails.cache.fetch(["keyword_analytics", current_user.id], expires_in: 5.minutes) do
      KeywordPerformanceService.new(current_user).analytics
    end
  end

  def integration_analytics
    Rails.cache.fetch(["integration_analytics", current_user.id], expires_in: 5.minutes) do
      IntegrationHealthService.new(current_user).analytics
    end
  end

  def recent_leads_widget
    current_user.leads
                .includes(:mention, :keyword)
                .order(created_at: :desc)
                .limit(10)
  end

  def keyword_performance_widget
    current_user.keywords
                .where('mentions_count > 0')
                .order(leads_count: :desc)
                .limit(5)
  end

  def integration_status_widget
    current_user.integrations.active
  end

  def conversion_metrics_widget
    {
      total_leads: current_user.leads_count,
      new_today: current_user.leads.today.count,
      conversion_rate: conversion_rate,
      top_keyword: top_performing_keyword
    }
  end

  def conversion_rate
    return 0 if current_user.mentions_count.zero?
    converted = current_user.leads.converted.count
    (converted.to_f / current_user.mentions_count * 100).round(2)
  end

  def top_performing_keyword
    current_user.keywords.order(leads_count: :desc).first&.keyword
  end
end
```

### 5. Model Updates for Counter Caches
```ruby
# app/models/keyword.rb
class Keyword < ApplicationRecord
  belongs_to :user, counter_cache: true
  has_many :mentions, dependent: :destroy, counter_cache: true
  has_many :leads, through: :mentions, counter_cache: true
  
  # Remove old count methods since we now use counter caches
  def conversion_rate
    return 0 if mentions_count.zero?
    (leads_count.to_f / mentions_count * 100).round(2)
  end
  
  def performance_score
    # Weighted score based on mentions and conversions
    (mentions_count * 0.3 + leads_count * 0.7).round
  end
end

# app/models/mention.rb
class Mention < ApplicationRecord
  belongs_to :keyword, counter_cache: true
  belongs_to :user, counter_cache: true
  has_one :analysis_result, dependent: :destroy
  has_one :lead, dependent: :destroy
  
  after_create :update_keyword_counters
  after_destroy :update_keyword_counters
  
  private
  
  def update_keyword_counters
    Keyword.reset_counters(keyword_id, :mentions, :leads)
  end
end

# app/models/lead.rb
class Lead < ApplicationRecord
  belongs_to :user, counter_cache: true
  belongs_to :mention
  has_one :keyword, through: :mention
  
  scope :today, -> { where(created_at: Date.current.all_day) }
  scope :converted, -> { where(status: 'converted') }
  scope :qualified, -> { where(status: 'qualified') }
  
  after_create :update_keyword_lead_count
  after_destroy :update_keyword_lead_count
  
  private
  
  def update_keyword_lead_count
    keyword.update_column(:leads_count, keyword.leads.count) if keyword
  end
end
```

## 🧪 Testing Strategy

### Performance Tests
```ruby
# test/performance/dashboard_performance_test.rb
require 'test_helper'
require 'benchmark'

class DashboardPerformanceTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    create_test_data
    sign_in @user
  end

  test "dashboard loads in under 500ms" do
    time = Benchmark.realtime do
      get dashboard_path
    end
    
    assert_response :success
    assert time < 0.5, "Dashboard took #{(time * 1000).round}ms to load (target: <500ms)"
  end

  test "dashboard makes fewer than 20 queries" do
    assert_sql_queries_count(max: 20) do
      get dashboard_path
    end
  end

  private

  def create_test_data
    10.times do
      keyword = @user.keywords.create!(keyword: Faker::Lorem.word)
      20.times do
        mention = keyword.mentions.create!(
          content: Faker::Lorem.paragraph,
          author: Faker::Name.name
        )
        Lead.create!(mention: mention, user: @user) if rand > 0.5
      end
    end
  end
end
```

## 📈 Monitoring & Validation

### Key Metrics to Track
1. **Response Times**
   - Dashboard load time
   - API endpoint response times
   - Database query times

2. **Database Performance**
   - Query count per request
   - Slow query log
   - Cache hit rates

3. **Application Metrics**
   - Memory usage
   - CPU utilization
   - Background job performance

### Success Criteria
- [ ] Dashboard loads in <500ms for 95th percentile
- [ ] Database queries reduced by >70%
- [ ] Memory usage reduced by >50%
- [ ] Zero N+1 query warnings in development
- [ ] All tests passing
- [ ] No performance regressions

## 🚀 Deployment Plan

### Pre-deployment
1. Run full test suite
2. Performance benchmark in staging
3. Database backup
4. Review rollback plan

### Deployment Steps
1. Deploy code changes
2. Run database migrations with zero downtime
3. Warm caches
4. Monitor performance metrics
5. Verify improvements

### Post-deployment
1. Monitor error rates
2. Track performance metrics
3. Gather user feedback
4. Document improvements

## 📝 Notes & Learnings

- Counter caches significantly reduce database load
- Proper indexing is critical for query performance
- Fragment caching provides immediate benefits
- Service objects improve code organization and testability
- Background job processing prevents request blocking

---

**Status**: In Progress  
**Started**: December 2024  
**Target Completion**: 2-3 weeks  
**Assigned Team**: Development Team