# Phase 2: Security Hardening

## 🎯 Objective
Implement enterprise-grade security measures to protect against vulnerabilities and enable compliance.

## 📅 Timeline: 1 Week

## ✅ Implementation Checklist

### Security Infrastructure

#### Rate Limiting
- [ ] Install and configure Rack::Attack gem
- [ ] Implement IP-based rate limiting
- [ ] Add user-based rate limiting for API
- [ ] Configure throttling for authentication endpoints
- [ ] Add blocklist/safelist functionality
- [ ] Set up rate limit headers in responses

#### Security Headers
- [ ] Implement Content Security Policy (CSP)
- [ ] Add X-Frame-Options header
- [ ] Configure X-Content-Type-Options
- [ ] Set up Strict-Transport-Security (HSTS)
- [ ] Add Referrer-Policy header
- [ ] Implement Permissions-Policy

#### API Authentication
- [ ] Install JWT gem
- [ ] Create API authentication controller
- [ ] Implement token generation
- [ ] Add token refresh mechanism
- [ ] Configure token expiration
- [ ] Add API key management

#### Audit & Monitoring
- [ ] Set up audit logging for sensitive operations
- [ ] Implement failed login tracking
- [ ] Add security event monitoring
- [ ] Configure automated security scanning
- [ ] Set up vulnerability alerting

## 🔧 Technical Implementation

### 1. Rack::Attack Configuration
```ruby
# Gemfile
gem 'rack-attack'
gem 'redis' # For distributed rate limiting

# config/initializers/rack_attack.rb
class Rack::Attack
  # Store configuration
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisStore.new

  # Safelist
  safelist('allow-localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1'
  end

  # Blocklist
  blocklist('block-bad-actors') do |req|
    # Block IPs from a database blocklist
    BlockedIp.where(ip: req.ip).exists?
  end

  # General rate limiting
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Strict rate limiting for authentication
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.ip
    end
  end

  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.params['user']['email'].to_s.downcase.gsub(/\s+/, "")
    end
  end

  # API rate limiting
  throttle('api/user', limit: 1000, period: 1.hour) do |req|
    if req.path.start_with?('/api/')
      req.env['warden'].user&.id
    end
  end

  # Exponential backoff for repeat offenders
  throttle('req/ip/aggressive', limit: 1, period: 1.second) do |req|
    req.ip if Rack::Attack::Fail2Ban.filter("req-#{req.ip}", maxretry: 10, findtime: 1.minute, bantime: 1.hour) { true }
  end

  # Custom response for rate limited requests
  self.throttled_response = lambda do |env|
    retry_after = (env['rack.attack.match_data'] || {})[:period]
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s,
        'X-RateLimit-Limit' => env['rack.attack.match_data'][:limit].to_s,
        'X-RateLimit-Remaining' => '0',
        'X-RateLimit-Reset' => (Time.now.to_i + retry_after).to_s
      },
      [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]
    ]
  end
end

# config/application.rb
config.middleware.use Rack::Attack
```

### 2. Security Headers Implementation
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :set_security_headers

  private

  def set_security_headers
    # Content Security Policy
    response.headers['Content-Security-Policy'] = csp_policy
    
    # Prevent clickjacking
    response.headers['X-Frame-Options'] = 'DENY'
    
    # Prevent MIME type sniffing
    response.headers['X-Content-Type-Options'] = 'nosniff'
    
    # Enable XSS protection
    response.headers['X-XSS-Protection'] = '1; mode=block'
    
    # Control referrer information
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    
    # Permissions Policy (formerly Feature Policy)
    response.headers['Permissions-Policy'] = permissions_policy
    
    # Strict Transport Security (already in Rails config)
    # response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
  end

  def csp_policy
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net",
      "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net",
      "font-src 'self' data: https://fonts.gstatic.com",
      "img-src 'self' data: https: blob:",
      "connect-src 'self' wss: https://api.openai.com",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'",
      "upgrade-insecure-requests"
    ].join('; ')
  end

  def permissions_policy
    [
      "accelerometer=()",
      "camera=()",
      "geolocation=()",
      "gyroscope=()",
      "magnetometer=()",
      "microphone=()",
      "payment=()",
      "usb=()"
    ].join(', ')
  end
end
```

### 3. JWT API Authentication
```ruby
# Gemfile
gem 'jwt'

# app/controllers/api/v1/base_controller.rb
class Api::V1::BaseController < ActionController::API
  before_action :authenticate_api_request!
  
  attr_reader :current_api_user

  private

  def authenticate_api_request!
    @current_api_user = AuthorizeApiRequest.call(request.headers).result
    render json: { error: 'Unauthorized' }, status: 401 unless @current_api_user
  end
end

# app/services/authorize_api_request.rb
class AuthorizeApiRequest
  prepend SimpleCommand

  def initialize(headers = {})
    @headers = headers
  end

  def call
    user
  end

  private

  attr_reader :headers

  def user
    @user ||= User.find(decoded_auth_token[:user_id]) if decoded_auth_token
    @user || errors.add(:token, 'Invalid token') && nil
  end

  def decoded_auth_token
    @decoded_auth_token ||= JsonWebToken.decode(http_auth_header)
  end

  def http_auth_header
    if headers['Authorization'].present?
      return headers['Authorization'].split(' ').last
    else
      errors.add(:token, 'Missing token')
    end
    nil
  end
end

# app/lib/json_web_token.rb
class JsonWebToken
  class << self
    def encode(payload, exp = 24.hours.from_now)
      payload[:exp] = exp.to_i
      JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
    end

    def decode(token)
      body = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')[0]
      HashWithIndifferentAccess.new body
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT Decode Error: #{e.message}"
      nil
    rescue JWT::ExpiredSignature
      Rails.logger.error "JWT Token Expired"
      nil
    end
  end
end

# app/controllers/api/v1/authentication_controller.rb
class Api::V1::AuthenticationController < ActionController::API
  skip_before_action :authenticate_api_request!, only: [:login, :refresh]

  def login
    user = User.find_by(email: params[:email])
    
    if user&.valid_password?(params[:password])
      token = JsonWebToken.encode(user_id: user.id)
      refresh_token = generate_refresh_token(user)
      
      render json: {
        token: token,
        refresh_token: refresh_token,
        exp: 24.hours.from_now.strftime("%m-%d-%Y %H:%M"),
        user: UserSerializer.new(user)
      }, status: :ok
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end

  def refresh
    refresh_token = params[:refresh_token]
    user = User.find_by(refresh_token: refresh_token)
    
    if user && user.refresh_token_valid?
      token = JsonWebToken.encode(user_id: user.id)
      render json: { token: token, exp: 24.hours.from_now.strftime("%m-%d-%Y %H:%M") }
    else
      render json: { error: 'Invalid refresh token' }, status: :unauthorized
    end
  end

  def logout
    current_api_user.update(refresh_token: nil, refresh_token_expires_at: nil)
    render json: { message: 'Logged out successfully' }
  end

  private

  def generate_refresh_token(user)
    token = SecureRandom.hex(32)
    user.update(
      refresh_token: token,
      refresh_token_expires_at: 30.days.from_now
    )
    token
  end
end
```

### 4. Audit Logging System
```ruby
# app/models/audit_log.rb
class AuditLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true
  
  enum action: {
    login: 0,
    logout: 1,
    create: 2,
    update: 3,
    delete: 4,
    export: 5,
    api_access: 6,
    failed_login: 7,
    permission_denied: 8,
    data_access: 9
  }
  
  enum severity: {
    info: 0,
    warning: 1,
    error: 2,
    critical: 3
  }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :suspicious, -> { where(severity: [:warning, :error, :critical]) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
  
  def self.log_activity(user:, action:, auditable: nil, details: {}, severity: :info, ip_address: nil)
    create!(
      user: user,
      action: action,
      auditable: auditable,
      details: details,
      severity: severity,
      ip_address: ip_address,
      user_agent: details[:user_agent],
      performed_at: Time.current
    )
  end
end

# app/controllers/concerns/auditable.rb
module Auditable
  extend ActiveSupport::Concern
  
  included do
    after_action :log_activity, except: [:index, :show]
  end
  
  private
  
  def log_activity
    return unless current_user
    
    action = action_name_to_audit_action
    return unless action
    
    AuditLog.log_activity(
      user: current_user,
      action: action,
      auditable: @auditable_resource,
      details: audit_details,
      ip_address: request.remote_ip,
      severity: audit_severity
    )
  end
  
  def action_name_to_audit_action
    case action_name
    when 'create' then :create
    when 'update' then :update
    when 'destroy' then :delete
    when 'export' then :export
    else nil
    end
  end
  
  def audit_details
    {
      controller: controller_name,
      action: action_name,
      params: filtered_params,
      user_agent: request.user_agent,
      referer: request.referer
    }
  end
  
  def filtered_params
    params.except(:password, :password_confirmation, :api_key, :api_secret).to_unsafe_h
  end
  
  def audit_severity
    case action_name
    when 'destroy' then :warning
    when 'export' then :info
    else :info
    end
  end
  
  def set_auditable_resource(resource)
    @auditable_resource = resource
  end
end

# Migration for audit logs
class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.references :user, foreign_key: true, index: true
      t.references :auditable, polymorphic: true, index: true
      t.integer :action, null: false
      t.integer :severity, default: 0
      t.jsonb :details, default: {}
      t.string :ip_address
      t.string :user_agent
      t.datetime :performed_at, null: false
      
      t.timestamps
    end
    
    add_index :audit_logs, :action
    add_index :audit_logs, :severity
    add_index :audit_logs, :performed_at
    add_index :audit_logs, [:user_id, :action]
    add_index :audit_logs, :details, using: :gin
  end
end
```

### 5. Security Monitoring Dashboard
```ruby
# app/controllers/admin/security_controller.rb
class Admin::SecurityController < ApplicationController
  before_action :authenticate_admin!
  
  def dashboard
    @failed_logins = AuditLog.failed_login.recent.limit(10)
    @suspicious_activities = AuditLog.suspicious.recent.limit(20)
    @blocked_ips = BlockedIp.active
    @rate_limit_violations = RateLimitViolation.recent.limit(10)
    @active_sessions = ActiveSession.includes(:user).active
    
    @security_metrics = {
      failed_logins_today: AuditLog.failed_login.where(performed_at: Date.current.all_day).count,
      blocked_ips_count: BlockedIp.active.count,
      rate_limit_hits: RateLimitViolation.where(created_at: 1.hour.ago..Time.current).count,
      suspicious_activities: AuditLog.suspicious.where(performed_at: Date.current.all_day).count
    }
  end
  
  def audit_logs
    @audit_logs = AuditLog.includes(:user, :auditable)
                          .recent
                          .page(params[:page])
  end
  
  def blocked_ips
    @blocked_ips = BlockedIp.includes(:blocked_by)
                            .order(created_at: :desc)
                            .page(params[:page])
  end
  
  def security_events
    @events = SecurityEvent.includes(:user)
                          .recent
                          .page(params[:page])
  end
end
```

## 🧪 Security Testing

### Security Test Suite
```ruby
# test/security/authentication_security_test.rb
class AuthenticationSecurityTest < ActionDispatch::IntegrationTest
  test "should block after 5 failed login attempts" do
    5.times do |i|
      post user_session_path, params: {
        user: { email: 'test@example.com', password: 'wrong' }
      }
      assert_response :unauthorized if i < 4
    end
    
    # 6th attempt should be rate limited
    post user_session_path, params: {
      user: { email: 'test@example.com', password: 'wrong' }
    }
    assert_response :too_many_requests
  end
  
  test "should include security headers" do
    get root_path
    
    assert response.headers['X-Frame-Options'].present?
    assert response.headers['X-Content-Type-Options'].present?
    assert response.headers['Content-Security-Policy'].present?
    assert response.headers['Referrer-Policy'].present?
  end
  
  test "API requires valid JWT token" do
    get api_v1_keywords_path
    assert_response :unauthorized
    
    user = users(:one)
    token = JsonWebToken.encode(user_id: user.id)
    
    get api_v1_keywords_path, headers: { 'Authorization': "Bearer #{token}" }
    assert_response :success
  end
end

# test/security/penetration_test.rb
class PenetrationTest < ActionDispatch::IntegrationTest
  test "prevents SQL injection" do
    get "/keywords?id=1' OR '1'='1"
    assert_response :not_found
  end
  
  test "prevents XSS attacks" do
    post keywords_path, params: {
      keyword: { keyword: "<script>alert('XSS')</script>" }
    }
    
    follow_redirect!
    assert_no_match /<script>/, response.body
  end
  
  test "prevents CSRF attacks" do
    # Remove CSRF token
    ActionController::Base.allow_forgery_protection = true
    
    post keywords_path, params: {
      keyword: { keyword: "test" }
    }, headers: { 'X-CSRF-Token': 'invalid' }
    
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
```

## 🚀 Deployment Checklist

### Pre-deployment
- [ ] Run security test suite
- [ ] Perform penetration testing
- [ ] Review OWASP Top 10 compliance
- [ ] Verify all secrets are encrypted
- [ ] Check for hardcoded credentials
- [ ] Review dependency vulnerabilities

### Deployment Steps
1. Deploy security configuration
2. Enable rate limiting gradually
3. Monitor for false positives
4. Adjust thresholds based on traffic
5. Enable audit logging
6. Verify security headers

### Post-deployment
- [ ] Monitor rate limit effectiveness
- [ ] Review audit logs for anomalies
- [ ] Check security header compliance
- [ ] Verify JWT authentication works
- [ ] Test API rate limiting
- [ ] Document security procedures

## 📊 Security Metrics

### Success Criteria
- [ ] Zero security vulnerabilities in automated scans
- [ ] 100% of endpoints protected by authentication
- [ ] Rate limiting prevents abuse
- [ ] All sensitive operations logged
- [ ] Security headers score A+ on securityheaders.com
- [ ] JWT tokens expire appropriately
- [ ] Failed login attempts tracked

### Monitoring
- Failed login attempts
- Rate limit violations
- Suspicious activity patterns
- API authentication failures
- Security header compliance
- Vulnerability scan results

---

**Status**: Ready for Implementation  
**Timeline**: 1 Week  
**Priority**: High  
**Risk Level**: Low (standard security practices)