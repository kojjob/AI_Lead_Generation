# Phase 4: Advanced Features - Team Collaboration & Automation

## 🎯 Objective
Enable enterprise growth through team collaboration, workflow automation, and integration ecosystem.

## 📅 Timeline: 4-5 Weeks

## ✅ Implementation Checklist

### Week 1-2: Team Collaboration

#### Multi-tenancy Foundation
- [ ] Create Organization model
- [ ] Implement team membership system
- [ ] Add role-based permissions (RBAC)
- [ ] Create team workspaces
- [ ] Implement resource sharing
- [ ] Add team billing management

#### Collaboration Features
- [ ] Team activity feed
- [ ] Shared campaigns
- [ ] Lead assignment system
- [ ] Team chat/comments
- [ ] Collaborative filters
- [ ] Team analytics dashboard

### Week 3-4: Workflow Automation

#### Automation Engine
- [ ] Create automation rules system
- [ ] Implement trigger mechanisms
- [ ] Build action executors
- [ ] Add condition evaluators
- [ ] Create workflow builder UI
- [ ] Implement scheduling system

#### Automated Workflows
- [ ] Lead scoring automation
- [ ] Auto-qualification rules
- [ ] Follow-up sequences
- [ ] Task creation triggers
- [ ] Email automation
- [ ] Notification rules

### Week 5: Integration Ecosystem

#### Webhook System
- [ ] Inbound webhook receiver
- [ ] Outbound webhook sender
- [ ] Webhook authentication
- [ ] Retry mechanism
- [ ] Event filtering
- [ ] Webhook management UI

#### Third-party Integrations
- [ ] CRM connectors (Salesforce, HubSpot)
- [ ] Email platforms (Mailchimp, SendGrid)
- [ ] Slack integration
- [ ] Zapier connector
- [ ] Microsoft Teams integration
- [ ] Google Workspace integration

## 🔧 Technical Implementation

### 1. Multi-tenancy Architecture
```ruby
# app/models/organization.rb
class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :teams, dependent: :destroy
  has_many :keywords, through: :teams
  has_many :leads, through: :teams
  has_many :campaigns, dependent: :destroy
  has_many :automation_rules, dependent: :destroy
  
  # Billing
  has_one :subscription, dependent: :destroy
  has_many :invoices, dependent: :destroy
  
  # Settings
  store_accessor :settings, :timezone, :locale, :currency, :features
  
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  
  before_validation :generate_slug
  
  scope :active, -> { joins(:subscription).where(subscriptions: { status: 'active' }) }
  
  def owner
    memberships.owner.first&.user
  end
  
  def admins
    users.joins(:memberships).where(memberships: { role: ['owner', 'admin'] })
  end
  
  def add_member(user, role: 'member')
    memberships.create!(user: user, role: role)
  end
  
  def remove_member(user)
    memberships.find_by(user: user)&.destroy
  end
  
  def has_feature?(feature)
    features&.include?(feature.to_s) || subscription&.plan&.has_feature?(feature)
  end
  
  private
  
  def generate_slug
    self.slug ||= name&.parameterize
  end
end

# app/models/membership.rb
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :team, optional: true
  
  enum role: {
    owner: 0,
    admin: 1,
    manager: 2,
    member: 3,
    viewer: 4
  }
  
  enum status: {
    active: 0,
    invited: 1,
    suspended: 2
  }
  
  validates :user_id, uniqueness: { scope: :organization_id }
  validate :organization_must_have_owner
  
  scope :active, -> { where(status: 'active') }
  scope :with_access, -> { where(role: ['owner', 'admin', 'manager', 'member']) }
  
  # Permissions
  def can_manage_organization?
    owner? || admin?
  end
  
  def can_manage_team?
    owner? || admin? || manager?
  end
  
  def can_manage_leads?
    !viewer?
  end
  
  def can_view_analytics?
    true # All roles can view analytics
  end
  
  def can_manage_integrations?
    owner? || admin?
  end
  
  def can_invite_members?
    owner? || admin? || manager?
  end
  
  private
  
  def organization_must_have_owner
    if role_changed? && role_was == 'owner'
      unless organization.memberships.where.not(id: id).owner.exists?
        errors.add(:role, "Organization must have at least one owner")
      end
    end
  end
end

# app/models/team.rb
class Team < ApplicationRecord
  belongs_to :organization
  has_many :team_members, class_name: 'Membership'
  has_many :users, through: :team_members
  has_many :keywords, dependent: :nullify
  has_many :leads, dependent: :nullify
  has_many :campaigns, dependent: :nullify
  
  validates :name, presence: true, uniqueness: { scope: :organization_id }
  
  scope :active, -> { where(active: true) }
  
  def add_member(user, role: 'member')
    membership = organization.memberships.find_by(user: user)
    membership&.update(team: self)
  end
  
  def remove_member(user)
    membership = organization.memberships.find_by(user: user, team: self)
    membership&.update(team: nil)
  end
end
```

### 2. Role-Based Access Control (RBAC)
```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record, :organization

  def initialize(user_context, record)
    @user = user_context.user
    @organization = user_context.organization
    @membership = user_context.membership
    @record = record
  end

  def index?
    @membership.present?
  end

  def show?
    @membership.present? && scope.exists?(@record.id)
  end

  def create?
    @membership&.can_manage_team?
  end

  def new?
    create?
  end

  def update?
    @membership&.can_manage_team? && scope.exists?(@record.id)
  end

  def edit?
    update?
  end

  def destroy?
    @membership&.can_manage_organization? && scope.exists?(@record.id)
  end

  def scope
    Pundit.policy_scope!(UserContext.new(@user, @organization, @membership), @record.class)
  end

  class Scope
    attr_reader :user, :scope, :organization, :membership

    def initialize(user_context, scope)
      @user = user_context.user
      @organization = user_context.organization
      @membership = user_context.membership
      @scope = scope
    end

    def resolve
      scope.all
    end
  end
end

# app/policies/keyword_policy.rb
class KeywordPolicy < ApplicationPolicy
  def index?
    @membership.present?
  end
  
  def show?
    @membership.present? && record_in_organization?
  end
  
  def create?
    @membership&.can_manage_team?
  end
  
  def update?
    @membership&.can_manage_team? && record_in_organization?
  end
  
  def destroy?
    @membership&.can_manage_team? && record_in_organization?
  end
  
  def activate?
    update?
  end
  
  def deactivate?
    update?
  end
  
  private
  
  def record_in_organization?
    @record.organization_id == @organization.id
  end
  
  class Scope < Scope
    def resolve
      scope.joins(:user).where(users: { organization_id: @organization.id })
    end
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit
  
  before_action :set_current_organization
  before_action :set_current_membership
  
  def pundit_user
    UserContext.new(current_user, current_organization, current_membership)
  end
  
  private
  
  def set_current_organization
    @current_organization = if params[:organization_id]
      current_user.organizations.find_by(slug: params[:organization_id])
    else
      current_user.organizations.first
    end
  end
  
  def set_current_membership
    @current_membership = current_user.memberships.find_by(organization: @current_organization)
  end
  
  def current_organization
    @current_organization
  end
  
  def current_membership
    @current_membership
  end
end

# app/models/user_context.rb
class UserContext
  attr_reader :user, :organization, :membership
  
  def initialize(user, organization, membership)
    @user = user
    @organization = organization
    @membership = membership
  end
end
```

### 3. Workflow Automation Engine
```ruby
# app/models/automation_rule.rb
class AutomationRule < ApplicationRecord
  belongs_to :organization
  belongs_to :created_by, class_name: 'User'
  has_many :automation_executions, dependent: :destroy
  
  # Triggers
  enum trigger_type: {
    new_mention: 0,
    new_lead: 1,
    lead_qualified: 2,
    lead_status_change: 3,
    keyword_threshold: 4,
    time_based: 5,
    manual: 6,
    webhook: 7
  }
  
  # Actions
  enum action_type: {
    send_email: 0,
    send_slack: 1,
    create_task: 2,
    update_lead_status: 3,
    assign_lead: 4,
    add_tag: 5,
    trigger_webhook: 6,
    create_notification: 7,
    update_lead_score: 8
  }
  
  store_accessor :trigger_conditions, :keyword_ids, :lead_statuses, :score_threshold, 
                  :time_delay, :schedule_cron, :webhook_secret
  store_accessor :action_parameters, :email_template, :slack_channel, :task_template,
                  :new_status, :assignee_id, :tags, :webhook_url, :score_adjustment
  
  validates :name, presence: true
  validates :trigger_type, presence: true
  validates :action_type, presence: true
  
  scope :active, -> { where(active: true) }
  scope :for_trigger, ->(trigger) { active.where(trigger_type: trigger) }
  
  def execute(triggering_object)
    return unless should_execute?(triggering_object)
    
    AutomationExecutionJob.perform_later(self, triggering_object)
    
    automation_executions.create!(
      triggered_by: triggering_object,
      executed_at: Time.current,
      status: 'pending'
    )
  end
  
  def should_execute?(object)
    return false unless active?
    
    case trigger_type
    when 'new_mention'
      check_mention_conditions(object)
    when 'new_lead', 'lead_qualified'
      check_lead_conditions(object)
    when 'lead_status_change'
      check_status_change_conditions(object)
    when 'keyword_threshold'
      check_keyword_threshold(object)
    when 'time_based'
      check_time_conditions
    else
      true
    end
  end
  
  private
  
  def check_mention_conditions(mention)
    return false if keyword_ids.present? && !keyword_ids.include?(mention.keyword_id.to_s)
    
    # Check mention score if configured
    if score_threshold.present?
      return false unless mention.analysis_result&.score.to_f >= score_threshold.to_f
    end
    
    true
  end
  
  def check_lead_conditions(lead)
    return false if lead_statuses.present? && !lead_statuses.include?(lead.status)
    
    # Check lead score
    if score_threshold.present?
      return false unless lead.score.to_f >= score_threshold.to_f
    end
    
    true
  end
  
  def check_status_change_conditions(lead)
    return false unless lead.saved_change_to_status?
    
    old_status, new_status = lead.saved_change_to_status
    
    # Check if status change matches conditions
    if trigger_conditions['from_status'].present?
      return false unless old_status == trigger_conditions['from_status']
    end
    
    if trigger_conditions['to_status'].present?
      return false unless new_status == trigger_conditions['to_status']
    end
    
    true
  end
  
  def check_keyword_threshold(keyword)
    case trigger_conditions['threshold_type']
    when 'mentions_count'
      keyword.mentions_count >= trigger_conditions['threshold_value'].to_i
    when 'leads_count'
      keyword.leads_count >= trigger_conditions['threshold_value'].to_i
    when 'conversion_rate'
      keyword.conversion_rate >= trigger_conditions['threshold_value'].to_f
    else
      false
    end
  end
  
  def check_time_conditions
    # For scheduled rules, check if it's time to run
    if schedule_cron.present?
      CronParser.new(schedule_cron).next_time <= Time.current
    else
      true
    end
  end
end

# app/jobs/automation_execution_job.rb
class AutomationExecutionJob < ApplicationJob
  queue_as :automations
  
  def perform(automation_rule, triggering_object)
    execution = automation_rule.automation_executions
                               .find_by(triggered_by: triggering_object, status: 'pending')
    
    return unless execution
    
    begin
      result = execute_action(automation_rule, triggering_object)
      
      execution.update!(
        status: 'completed',
        completed_at: Time.current,
        result: result
      )
    rescue => e
      execution.update!(
        status: 'failed',
        error_message: e.message,
        failed_at: Time.current
      )
      
      raise e
    end
  end
  
  private
  
  def execute_action(rule, object)
    case rule.action_type
    when 'send_email'
      send_email_action(rule, object)
    when 'send_slack'
      send_slack_action(rule, object)
    when 'create_task'
      create_task_action(rule, object)
    when 'update_lead_status'
      update_lead_status_action(rule, object)
    when 'assign_lead'
      assign_lead_action(rule, object)
    when 'add_tag'
      add_tag_action(rule, object)
    when 'trigger_webhook'
      trigger_webhook_action(rule, object)
    when 'create_notification'
      create_notification_action(rule, object)
    when 'update_lead_score'
      update_lead_score_action(rule, object)
    end
  end
  
  def send_email_action(rule, object)
    template = rule.action_parameters['email_template']
    recipient = determine_recipient(rule, object)
    
    AutomationMailer.send_automation_email(
      recipient: recipient,
      template: template,
      object: object
    ).deliver_later
    
    { email_sent_to: recipient }
  end
  
  def send_slack_action(rule, object)
    SlackNotificationService.new(
      channel: rule.action_parameters['slack_channel'],
      message: build_slack_message(rule, object)
    ).send
    
    { slack_message_sent: true }
  end
  
  def create_task_action(rule, object)
    task = Task.create!(
      organization: rule.organization,
      title: interpolate_template(rule.action_parameters['task_title'], object),
      description: interpolate_template(rule.action_parameters['task_description'], object),
      assignee_id: rule.action_parameters['assignee_id'],
      due_date: calculate_due_date(rule),
      related_to: object
    )
    
    { task_created: task.id }
  end
  
  def update_lead_status_action(rule, lead)
    old_status = lead.status
    lead.update!(status: rule.action_parameters['new_status'])
    
    { status_changed: { from: old_status, to: lead.status } }
  end
  
  def assign_lead_action(rule, lead)
    assignee = User.find(rule.action_parameters['assignee_id'])
    lead.update!(assigned_to: assignee)
    
    { lead_assigned_to: assignee.id }
  end
  
  def trigger_webhook_action(rule, object)
    WebhookService.new(
      url: rule.action_parameters['webhook_url'],
      payload: build_webhook_payload(object),
      secret: rule.action_parameters['webhook_secret']
    ).trigger
    
    { webhook_triggered: true }
  end
end
```

### 4. Webhook System
```ruby
# app/models/webhook.rb
class Webhook < ApplicationRecord
  belongs_to :organization
  has_many :webhook_deliveries, dependent: :destroy
  
  EVENTS = %w[
    lead.created lead.qualified lead.converted
    mention.created mention.analyzed
    keyword.threshold_reached
    integration.connected integration.disconnected
  ].freeze
  
  validates :url, presence: true, format: URI::regexp(%w[http https])
  validates :events, presence: true
  validate :events_are_valid
  
  scope :active, -> { where(active: true) }
  scope :for_event, ->(event) { active.where('? = ANY(events)', event) }
  
  def deliver(event, payload)
    webhook_deliveries.create!(
      event: event,
      payload: payload,
      status: 'pending'
    )
    
    WebhookDeliveryJob.perform_later(self, event, payload)
  end
  
  def verify_signature(payload, signature)
    expected = generate_signature(payload)
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end
  
  def generate_signature(payload)
    OpenSSL::HMAC.hexdigest('SHA256', secret, payload.to_json)
  end
  
  private
  
  def events_are_valid
    invalid_events = events - EVENTS
    errors.add(:events, "contains invalid events: #{invalid_events.join(', ')}") if invalid_events.any?
  end
end

# app/jobs/webhook_delivery_job.rb
class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 5
  
  def perform(webhook, event, payload)
    delivery = webhook.webhook_deliveries.find_by(
      event: event,
      payload: payload,
      status: 'pending'
    )
    
    return unless delivery
    
    begin
      response = deliver_webhook(webhook, event, payload)
      
      delivery.update!(
        status: 'delivered',
        response_code: response.code,
        response_body: response.body,
        delivered_at: Time.current
      )
    rescue => e
      delivery.update!(
        status: 'failed',
        error_message: e.message,
        failed_at: Time.current,
        retry_count: delivery.retry_count + 1
      )
      
      raise e if delivery.retry_count < 5
    end
  end
  
  private
  
  def deliver_webhook(webhook, event, payload)
    HTTParty.post(
      webhook.url,
      body: payload.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-Webhook-Event' => event,
        'X-Webhook-Signature' => webhook.generate_signature(payload),
        'X-Webhook-Id' => webhook.id.to_s
      },
      timeout: 30
    )
  end
end
```

### 5. Third-party Integration Connectors
```ruby
# app/services/crm_connector.rb
class CrmConnector
  def self.for(platform)
    case platform
    when 'salesforce'
      SalesforceConnector.new
    when 'hubspot'
      HubspotConnector.new
    when 'pipedrive'
      PipedriveConnector.new
    else
      raise NotImplementedError, "CRM platform #{platform} not supported"
    end
  end
end

# app/services/salesforce_connector.rb
class SalesforceConnector
  def initialize(integration)
    @integration = integration
    @client = Restforce.new(
      oauth_token: integration.access_token,
      refresh_token: integration.refresh_token,
      instance_url: integration.instance_url,
      client_id: Rails.application.credentials.salesforce_client_id,
      client_secret: Rails.application.credentials.salesforce_client_secret
    )
  end
  
  def sync_lead(lead)
    salesforce_lead = {
      'FirstName' => lead.first_name,
      'LastName' => lead.last_name,
      'Email' => lead.email,
      'Company' => lead.company,
      'Title' => lead.title,
      'LeadSource' => 'AI Lead Generation',
      'Description' => lead.notes,
      'Status' => map_lead_status(lead.status),
      'Rating' => calculate_rating(lead.score)
    }
    
    if lead.salesforce_id.present?
      @client.update('Lead', lead.salesforce_id, salesforce_lead)
    else
      result = @client.create('Lead', salesforce_lead)
      lead.update(salesforce_id: result.id) if result.success?
    end
    
    result
  end
  
  def fetch_leads(since: 1.day.ago)
    query = "SELECT Id, FirstName, LastName, Email, Company, Title, Status, Rating, CreatedDate 
             FROM Lead 
             WHERE CreatedDate > #{since.iso8601} 
             AND LeadSource = 'AI Lead Generation'"
    
    @client.query(query).map do |record|
      {
        salesforce_id: record.Id,
        first_name: record.FirstName,
        last_name: record.LastName,
        email: record.Email,
        company: record.Company,
        title: record.Title,
        status: map_salesforce_status(record.Status),
        score: calculate_score(record.Rating),
        created_at: record.CreatedDate
      }
    end
  end
  
  private
  
  def map_lead_status(status)
    {
      'new' => 'Open - Not Contacted',
      'contacted' => 'Working - Contacted',
      'qualified' => 'Qualified',
      'converted' => 'Closed - Converted'
    }[status] || 'Open'
  end
  
  def map_salesforce_status(sf_status)
    {
      'Open - Not Contacted' => 'new',
      'Working - Contacted' => 'contacted',
      'Qualified' => 'qualified',
      'Closed - Converted' => 'converted'
    }.fetch(sf_status, 'new')
  end
  
  def calculate_rating(score)
    case score
    when 80..100 then 'Hot'
    when 60..79 then 'Warm'
    when 40..59 then 'Cold'
    else 'Cold'
    end
  end
  
  def calculate_score(rating)
    {
      'Hot' => 90,
      'Warm' => 70,
      'Cold' => 40
    }.fetch(rating, 50)
  end
end
```

## 🧪 Testing Strategy

### Team Collaboration Testing
```ruby
# test/models/organization_test.rb
class OrganizationTest < ActiveSupport::TestCase
  test "should create organization with owner" do
    user = users(:one)
    org = Organization.create!(name: "Test Org")
    membership = org.add_member(user, role: 'owner')
    
    assert_equal 'owner', membership.role
    assert_equal user, org.owner
  end
  
  test "should enforce unique organization names" do
    Organization.create!(name: "Unique Org")
    duplicate = Organization.new(name: "Unique Org")
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end
  
  test "should not allow removing last owner" do
    org = organizations(:one)
    owner_membership = org.memberships.owner.first
    
    owner_membership.role = 'admin'
    assert_not owner_membership.valid?
    assert_includes owner_membership.errors[:role], "Organization must have at least one owner"
  end
end
```

### Automation Testing
```ruby
# test/models/automation_rule_test.rb
class AutomationRuleTest < ActiveSupport::TestCase
  test "should execute rule when conditions met" do
    rule = automation_rules(:email_on_qualified_lead)
    lead = leads(:new_lead)
    
    lead.update!(status: 'qualified')
    
    assert_enqueued_with(job: AutomationExecutionJob) do
      rule.execute(lead)
    end
  end
  
  test "should not execute inactive rules" do
    rule = automation_rules(:inactive_rule)
    lead = leads(:new_lead)
    
    assert_no_enqueued_jobs do
      rule.execute(lead)
    end
  end
  
  test "should check trigger conditions" do
    rule = automation_rules(:score_threshold_rule)
    rule.trigger_conditions = { 'score_threshold' => 80 }
    
    low_score_lead = leads(:low_score_lead)
    high_score_lead = leads(:high_score_lead)
    
    assert_not rule.should_execute?(low_score_lead)
    assert rule.should_execute?(high_score_lead)
  end
end
```

## 🚀 Deployment Plan

### Pre-deployment
- [ ] Database migrations tested
- [ ] Permission system verified
- [ ] Automation engine tested
- [ ] Webhook security reviewed
- [ ] Integration credentials configured

### Deployment Steps
1. Deploy database migrations
2. Configure organization settings
3. Set up permission system
4. Enable automation engine
5. Configure webhook endpoints
6. Test integrations

### Post-deployment
- [ ] Monitor automation executions
- [ ] Track webhook deliveries
- [ ] Verify team permissions
- [ ] Test CRM sync
- [ ] Gather user feedback

---

**Status**: Ready for Implementation  
**Timeline**: 4-5 Weeks  
**Priority**: Medium  
**Business Impact**: Enables enterprise sales and team collaboration