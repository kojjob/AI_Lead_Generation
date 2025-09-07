# Phase 3: Core Feature Development

## 🎯 Objective
Build REST API, real-time features, and advanced analytics to unlock new business opportunities.

## 📅 Timeline: 3-4 Weeks

## ✅ Implementation Checklist

### Week 1: REST API Development

#### API Foundation
- [ ] Create API namespace and routing
- [ ] Implement API base controller
- [ ] Add JWT authentication
- [ ] Create API documentation
- [ ] Set up versioning strategy
- [ ] Implement rate limiting

#### Core Endpoints
- [ ] Keywords CRUD endpoints
- [ ] Mentions read endpoints
- [ ] Leads management endpoints
- [ ] Integrations endpoints
- [ ] Analytics endpoints
- [ ] User profile endpoints

### Week 2: Real-time Features

#### WebSocket Infrastructure
- [ ] Configure ActionCable
- [ ] Create notification channel
- [ ] Implement presence tracking
- [ ] Add connection authentication
- [ ] Set up Redis for pub/sub

#### Real-time Notifications
- [ ] New mention notifications
- [ ] Lead qualification alerts
- [ ] Integration status updates
- [ ] System announcements
- [ ] Browser push notifications

### Week 3-4: Advanced Analytics

#### Analytics Dashboard
- [ ] Data visualization library integration
- [ ] Custom date range selectors
- [ ] Interactive charts and graphs
- [ ] Export functionality (CSV/PDF)
- [ ] Saved report templates
- [ ] Scheduled report generation

## 🔧 Technical Implementation

### 1. REST API Structure
```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    # Authentication
    post 'auth/login', to: 'authentication#login'
    post 'auth/refresh', to: 'authentication#refresh'
    delete 'auth/logout', to: 'authentication#logout'
    
    # Resources
    resources :keywords do
      resources :mentions, only: [:index, :show]
      member do
        post :activate
        post :deactivate
        get :analytics
      end
    end
    
    resources :leads do
      member do
        post :qualify
        post :contact
        post :convert
        patch :update_status
      end
      collection do
        post :bulk_action
        get :export
      end
    end
    
    resources :integrations do
      member do
        post :connect
        post :disconnect
        post :sync
        get :health
      end
    end
    
    # Analytics
    namespace :analytics do
      get :overview
      get :leads
      get :keywords
      get :conversions
      get :timeline
    end
    
    # User
    resource :profile, only: [:show, :update]
    resources :notifications, only: [:index, :update]
  end
end
```

### 2. API Controllers Implementation
```ruby
# app/controllers/api/v1/keywords_controller.rb
class Api::V1::KeywordsController < Api::V1::BaseController
  before_action :set_keyword, except: [:index, :create]
  
  def index
    keywords = current_api_user.keywords
                               .includes(:mentions, :leads)
                               .page(params[:page])
                               .per(params[:per_page] || 20)
    
    render json: {
      data: KeywordSerializer.new(keywords).serializable_hash,
      meta: pagination_meta(keywords)
    }
  end
  
  def show
    render json: KeywordSerializer.new(@keyword, include: [:mentions, :leads])
  end
  
  def create
    keyword = current_api_user.keywords.build(keyword_params)
    
    if keyword.save
      render json: KeywordSerializer.new(keyword), status: :created
    else
      render json: { errors: keyword.errors }, status: :unprocessable_entity
    end
  end
  
  def update
    if @keyword.update(keyword_params)
      render json: KeywordSerializer.new(@keyword)
    else
      render json: { errors: @keyword.errors }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @keyword.destroy
    head :no_content
  end
  
  def activate
    @keyword.update(active: true)
    render json: KeywordSerializer.new(@keyword)
  end
  
  def deactivate
    @keyword.update(active: false)
    render json: KeywordSerializer.new(@keyword)
  end
  
  def analytics
    analytics = KeywordAnalyticsService.new(@keyword).generate
    render json: analytics
  end
  
  private
  
  def set_keyword
    @keyword = current_api_user.keywords.find(params[:id])
  end
  
  def keyword_params
    params.require(:keyword).permit(:keyword, :type, :status, :active, :notes, 
                                    :priority, :notification_frequency, 
                                    :search_parameters, platforms: [])
  end
  
  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      next_page: collection.next_page,
      prev_page: collection.prev_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count
    }
  end
end

# app/serializers/keyword_serializer.rb
class KeywordSerializer
  include JSONAPI::Serializer
  
  attributes :id, :keyword, :type, :status, :active, :priority, 
             :notification_frequency, :platforms, :created_at, :updated_at
  
  attribute :mentions_count do |keyword|
    keyword.mentions_count
  end
  
  attribute :leads_count do |keyword|
    keyword.leads_count
  end
  
  attribute :conversion_rate do |keyword|
    keyword.conversion_rate
  end
  
  attribute :performance_score do |keyword|
    keyword.performance_score
  end
  
  has_many :mentions
  has_many :leads
end
```

### 3. WebSocket Real-time Features
```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      if verified_user = env['warden'].user
        verified_user
      else
        reject_unauthorized_connection
      end
    end
  end
end

# app/channels/notifications_channel.rb
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notifications_#{current_user.id}"
    stream_from "notifications_global"
    
    # Track user presence
    ActionCable.server.pubsub.redis_connection_for_subscriptions.sadd(
      "online_users", 
      current_user.id
    )
  end
  
  def unsubscribed
    # Remove from online users
    ActionCable.server.pubsub.redis_connection_for_subscriptions.srem(
      "online_users",
      current_user.id
    )
  end
  
  def mark_as_read(data)
    notification = current_user.notifications.find(data['notification_id'])
    notification.update(read: true)
    
    broadcast_to current_user, {
      type: 'notification_read',
      notification_id: notification.id
    }
  end
end

# app/channels/dashboard_channel.rb
class DashboardChannel < ApplicationCable::Channel
  def subscribed
    stream_from "dashboard_#{current_user.id}"
  end
  
  def request_update(data)
    widget = data['widget']
    
    case widget
    when 'recent_leads'
      broadcast_recent_leads
    when 'keyword_performance'
      broadcast_keyword_performance
    when 'analytics'
      broadcast_analytics
    end
  end
  
  private
  
  def broadcast_recent_leads
    leads = current_user.leads
                        .includes(:mention, :keyword)
                        .order(created_at: :desc)
                        .limit(10)
    
    broadcast_to current_user, {
      type: 'widget_update',
      widget: 'recent_leads',
      data: LeadSerializer.new(leads).serializable_hash
    }
  end
  
  def broadcast_keyword_performance
    keywords = current_user.keywords
                          .where('mentions_count > 0')
                          .order(leads_count: :desc)
                          .limit(5)
    
    broadcast_to current_user, {
      type: 'widget_update',
      widget: 'keyword_performance',
      data: KeywordSerializer.new(keywords).serializable_hash
    }
  end
  
  def broadcast_analytics
    analytics = DashboardService.new(current_user).analytics_data
    
    broadcast_to current_user, {
      type: 'widget_update',
      widget: 'analytics',
      data: analytics
    }
  end
end

# app/jobs/notification_broadcast_job.rb
class NotificationBroadcastJob < ApplicationJob
  queue_as :default
  
  def perform(notification)
    NotificationsChannel.broadcast_to(
      notification.user,
      {
        type: 'new_notification',
        notification: NotificationSerializer.new(notification).serializable_hash
      }
    )
    
    # Send browser push notification if enabled
    if notification.user.push_notifications_enabled?
      send_push_notification(notification)
    end
    
    # Send email notification if enabled
    if notification.user.email_notifications_enabled?
      NotificationMailer.new_notification(notification).deliver_later
    end
  end
  
  private
  
  def send_push_notification(notification)
    WebPush.payload_send(
      endpoint: notification.user.push_endpoint,
      message: notification.message,
      p256dh: notification.user.push_p256dh,
      auth: notification.user.push_auth,
      vapid: {
        subject: "mailto:notifications@example.com",
        public_key: Rails.application.credentials.vapid_public_key,
        private_key: Rails.application.credentials.vapid_private_key
      }
    )
  end
end
```

### 4. Advanced Analytics Implementation
```ruby
# app/services/analytics_service.rb
class AnalyticsService
  def initialize(user, date_range = nil)
    @user = user
    @date_range = date_range || default_date_range
  end
  
  def overview
    {
      summary: summary_metrics,
      trends: trend_analysis,
      performance: performance_metrics,
      projections: future_projections
    }
  end
  
  def lead_analytics
    {
      acquisition: lead_acquisition_funnel,
      quality: lead_quality_analysis,
      conversion: conversion_analysis,
      timeline: lead_timeline,
      sources: lead_sources
    }
  end
  
  def keyword_analytics
    {
      performance: keyword_performance_matrix,
      trends: keyword_trends,
      opportunities: keyword_opportunities,
      competitive: competitive_analysis
    }
  end
  
  def conversion_funnel
    {
      stages: funnel_stages,
      drop_off: drop_off_analysis,
      velocity: conversion_velocity,
      optimization: optimization_opportunities
    }
  end
  
  private
  
  def summary_metrics
    {
      total_mentions: mentions_in_range.count,
      total_leads: leads_in_range.count,
      qualified_leads: leads_in_range.qualified.count,
      converted_leads: leads_in_range.converted.count,
      conversion_rate: calculate_conversion_rate,
      average_lead_score: calculate_average_lead_score,
      response_time: calculate_average_response_time
    }
  end
  
  def trend_analysis
    {
      daily_leads: daily_lead_trend,
      weekly_comparison: weekly_comparison,
      monthly_growth: monthly_growth_rate,
      seasonal_patterns: detect_seasonal_patterns
    }
  end
  
  def performance_metrics
    {
      top_keywords: top_performing_keywords,
      top_sources: top_lead_sources,
      best_times: optimal_posting_times,
      engagement_rates: calculate_engagement_rates
    }
  end
  
  def future_projections
    {
      expected_leads: project_future_leads,
      expected_conversions: project_conversions,
      growth_trajectory: calculate_growth_trajectory,
      recommendations: generate_recommendations
    }
  end
  
  def lead_acquisition_funnel
    stages = {
      impressions: calculate_impressions,
      mentions: mentions_in_range.count,
      qualified: leads_in_range.qualified.count,
      contacted: leads_in_range.contacted.count,
      converted: leads_in_range.converted.count
    }
    
    stages.merge(calculate_funnel_conversion_rates(stages))
  end
  
  def keyword_performance_matrix
    @user.keywords.map do |keyword|
      {
        keyword: keyword.keyword,
        mentions: keyword.mentions.where(created_at: @date_range).count,
        leads: keyword.leads.where(created_at: @date_range).count,
        conversion_rate: keyword.conversion_rate,
        trend: calculate_keyword_trend(keyword),
        score: keyword.performance_score
      }
    end.sort_by { |k| -k[:score] }
  end
  
  def daily_lead_trend
    leads_in_range.group_by_day(:created_at).count
  end
  
  def weekly_comparison
    current_week = leads_in_range.where(created_at: 1.week.ago..Time.current).count
    previous_week = leads_in_range.where(created_at: 2.weeks.ago..1.week.ago).count
    
    {
      current: current_week,
      previous: previous_week,
      change: calculate_percentage_change(previous_week, current_week)
    }
  end
  
  def calculate_conversion_rate
    total = mentions_in_range.count
    return 0 if total.zero?
    
    converted = leads_in_range.converted.count
    (converted.to_f / total * 100).round(2)
  end
  
  def mentions_in_range
    @user.mentions.where(created_at: @date_range)
  end
  
  def leads_in_range
    @user.leads.where(created_at: @date_range)
  end
  
  def default_date_range
    30.days.ago..Time.current
  end
  
  def calculate_percentage_change(old_value, new_value)
    return 0 if old_value.zero?
    ((new_value - old_value).to_f / old_value * 100).round(2)
  end
end

# app/controllers/api/v1/analytics_controller.rb
class Api::V1::AnalyticsController < Api::V1::BaseController
  before_action :set_date_range
  
  def overview
    analytics = AnalyticsService.new(current_api_user, @date_range).overview
    render json: analytics
  end
  
  def leads
    analytics = AnalyticsService.new(current_api_user, @date_range).lead_analytics
    render json: analytics
  end
  
  def keywords
    analytics = AnalyticsService.new(current_api_user, @date_range).keyword_analytics
    render json: analytics
  end
  
  def conversions
    analytics = AnalyticsService.new(current_api_user, @date_range).conversion_funnel
    render json: analytics
  end
  
  def timeline
    data = {
      mentions: mentions_timeline,
      leads: leads_timeline,
      conversions: conversions_timeline
    }
    render json: data
  end
  
  private
  
  def set_date_range
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current
    @date_range = start_date..end_date
  end
  
  def mentions_timeline
    current_api_user.mentions
                    .where(created_at: @date_range)
                    .group_by_day(:created_at)
                    .count
  end
  
  def leads_timeline
    current_api_user.leads
                    .where(created_at: @date_range)
                    .group_by_day(:created_at)
                    .count
  end
  
  def conversions_timeline
    current_api_user.leads
                    .converted
                    .where(created_at: @date_range)
                    .group_by_day(:created_at)
                    .count
  end
end
```

### 5. Frontend JavaScript for Real-time Updates
```javascript
// app/javascript/channels/notifications_channel.js
import consumer from "./consumer"

const notificationsChannel = consumer.subscriptions.create("NotificationsChannel", {
  connected() {
    console.log("Connected to notifications channel")
    this.requestNotifications()
  },

  disconnected() {
    console.log("Disconnected from notifications channel")
  },

  received(data) {
    switch(data.type) {
      case 'new_notification':
        this.handleNewNotification(data.notification)
        break
      case 'notification_read':
        this.handleNotificationRead(data.notification_id)
        break
    }
  },

  requestNotifications() {
    this.perform('request_notifications')
  },

  markAsRead(notificationId) {
    this.perform('mark_as_read', { notification_id: notificationId })
  },

  handleNewNotification(notification) {
    // Show browser notification
    if (Notification.permission === "granted") {
      new Notification(notification.title, {
        body: notification.message,
        icon: '/icon.png',
        tag: `notification-${notification.id}`
      })
    }
    
    // Update UI
    this.updateNotificationBadge()
    this.addNotificationToList(notification)
    
    // Show toast notification
    this.showToast(notification.message)
  },

  updateNotificationBadge() {
    const badge = document.querySelector('.notification-badge')
    if (badge) {
      const count = parseInt(badge.textContent) || 0
      badge.textContent = count + 1
      badge.classList.remove('hidden')
    }
  },

  addNotificationToList(notification) {
    const list = document.querySelector('#notifications-list')
    if (list) {
      const item = this.createNotificationElement(notification)
      list.prepend(item)
    }
  },

  createNotificationElement(notification) {
    const div = document.createElement('div')
    div.className = 'notification-item unread'
    div.dataset.notificationId = notification.id
    div.innerHTML = `
      <div class="notification-content">
        <h4>${notification.title}</h4>
        <p>${notification.message}</p>
        <time>${new Date(notification.created_at).toLocaleString()}</time>
      </div>
    `
    div.addEventListener('click', () => this.markAsRead(notification.id))
    return div
  },

  showToast(message) {
    // Implement toast notification
    const toast = document.createElement('div')
    toast.className = 'toast-notification'
    toast.textContent = message
    document.body.appendChild(toast)
    
    setTimeout(() => toast.classList.add('show'), 100)
    setTimeout(() => {
      toast.classList.remove('show')
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }
})

// app/javascript/channels/dashboard_channel.js
import consumer from "./consumer"
import { updateWidget } from "../dashboard"

const dashboardChannel = consumer.subscriptions.create("DashboardChannel", {
  connected() {
    console.log("Connected to dashboard channel")
    this.scheduleUpdates()
  },

  disconnected() {
    console.log("Disconnected from dashboard channel")
    this.clearScheduledUpdates()
  },

  received(data) {
    if (data.type === 'widget_update') {
      updateWidget(data.widget, data.data)
    }
  },

  requestUpdate(widget) {
    this.perform('request_update', { widget: widget })
  },

  scheduleUpdates() {
    // Update different widgets at different intervals
    this.intervals = {
      recent_leads: setInterval(() => this.requestUpdate('recent_leads'), 30000),
      keyword_performance: setInterval(() => this.requestUpdate('keyword_performance'), 60000),
      analytics: setInterval(() => this.requestUpdate('analytics'), 120000)
    }
  },

  clearScheduledUpdates() {
    Object.values(this.intervals).forEach(interval => clearInterval(interval))
  }
})
```

## 🧪 Testing Strategy

### API Testing
```ruby
# test/controllers/api/v1/keywords_controller_test.rb
class Api::V1::KeywordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    @headers = { 'Authorization': "Bearer #{@token}" }
  end
  
  test "should get index with authentication" do
    get api_v1_keywords_path, headers: @headers
    assert_response :success
    
    json = JSON.parse(response.body)
    assert json['data'].is_a?(Array)
    assert json['meta'].present?
  end
  
  test "should not get index without authentication" do
    get api_v1_keywords_path
    assert_response :unauthorized
  end
  
  test "should create keyword" do
    assert_difference('Keyword.count') do
      post api_v1_keywords_path, params: {
        keyword: { keyword: 'test keyword', priority: 'high' }
      }, headers: @headers
    end
    
    assert_response :created
  end
  
  test "should handle pagination" do
    get api_v1_keywords_path, params: { page: 2, per_page: 5 }, headers: @headers
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 2, json['meta']['current_page']
  end
end
```

### WebSocket Testing
```ruby
# test/channels/notifications_channel_test.rb
class NotificationsChannelTest < ActionCable::Channel::TestCase
  setup do
    @user = users(:one)
  end
  
  test "subscribes with authenticated user" do
    stub_connection current_user: @user
    
    subscribe
    assert subscription.confirmed?
    assert_has_stream "notifications_#{@user.id}"
    assert_has_stream "notifications_global"
  end
  
  test "broadcasts new notification" do
    stub_connection current_user: @user
    subscribe
    
    notification = notifications(:one)
    
    assert_broadcast_on("notifications_#{@user.id}", 
      type: 'new_notification',
      notification: NotificationSerializer.new(notification).serializable_hash
    ) do
      NotificationBroadcastJob.perform_now(notification)
    end
  end
end
```

## 🚀 Deployment Plan

### Pre-deployment
- [ ] API documentation complete
- [ ] Rate limiting configured
- [ ] WebSocket scaling tested
- [ ] Analytics queries optimized
- [ ] Security review passed

### Deployment Steps
1. Deploy API infrastructure
2. Configure WebSocket connections
3. Set up Redis for ActionCable
4. Deploy frontend updates
5. Enable real-time features
6. Monitor performance

### Post-deployment
- [ ] API usage monitoring
- [ ] WebSocket connection tracking
- [ ] Analytics accuracy verification
- [ ] Performance benchmarking
- [ ] User feedback collection

---

**Status**: Ready for Implementation  
**Timeline**: 3-4 Weeks  
**Priority**: High  
**Business Impact**: Unlocks mobile apps, integrations, and real-time features