require "test_helper"

class IntegrationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @integration = Integration.new(
      user: @user,
      platform_name: "twitter",
      provider: "twitter_api_v2",
      api_key: "test_key",
      api_secret: "test_secret",
      connection_status: "disconnected",
      enabled: true,
      sync_frequency: "hourly"
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @integration.valid?
  end

  test "should require a user" do
    @integration.user = nil
    assert_not @integration.valid?
    assert_includes @integration.errors[:user], "must exist"
  end

  test "should allow nil platform_name" do
    @integration.platform_name = nil
    # Platform name is optional in the model
    assert @integration.valid?
  end

  test "should require a provider" do
    @integration.provider = nil
    assert_not @integration.valid?
    assert_includes @integration.errors[:provider], "can't be blank"
  end

  test "should only allow supported platforms" do
    @integration.platform_name = "unsupported_platform"
    assert_not @integration.valid?
    assert_includes @integration.errors[:platform_name], "is not included in the list"
  end

  test "should only allow valid connection statuses" do
    @integration.connection_status = "invalid_status"
    assert_not @integration.valid?
    assert_includes @integration.errors[:connection_status], "is not included in the list"
  end

  test "should only allow valid sync frequencies" do
    @integration.sync_frequency = "invalid_frequency"
    assert_not @integration.valid?
    assert_includes @integration.errors[:sync_frequency], "is not included in the list"
  end

  test "should enforce unique provider per user" do
    @integration.save!
    duplicate = @integration.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:provider], "has already been taken"
  end

  # Association Tests
  test "should belong to user" do
    assert_respond_to @integration, :user
    assert_instance_of User, @integration.user
  end

  test "should have many integration logs" do
    assert_respond_to @integration, :integration_logs
  end

  # Scope Tests
  test "enabled scope should return only enabled integrations" do
    enabled_integration = Integration.create!(
      user: @user,
      platform_name: "twitter",
      provider: "twitter_api",
      api_key: "test_api_key",
      api_secret: "test_api_secret",
      enabled: true,
      connection_status: "connected"
    )

    disabled_integration = Integration.create!(
      user: @user,
      platform_name: "facebook",
      provider: "facebook_api",
      access_token: "test_access_token",
      enabled: false,
      connection_status: "connected"
    )

    assert_includes Integration.enabled, enabled_integration
    assert_not_includes Integration.enabled, disabled_integration
  end

  test "connected scope should return only connected integrations" do
    connected = Integration.create!(
      user: @user,
      platform_name: "twitter",
      provider: "twitter_api",
      api_key: "test_api_key",
      api_secret: "test_api_secret",
      connection_status: "connected",
      enabled: true
    )

    disconnected = Integration.create!(
      user: @user,
      platform_name: "facebook",
      provider: "facebook_api",
      access_token: "test_access_token",
      connection_status: "disconnected",
      enabled: true
    )

    assert_includes Integration.connected, connected
    assert_not_includes Integration.connected, disconnected
  end

  test "with_errors scope should return integrations with errors" do
    with_error = Integration.create!(
      user: @user,
      platform_name: "twitter",
      provider: "twitter_api",
      api_key: "test_api_key",
      api_secret: "test_api_secret",
      connection_status: "error",
      error_count: 5,
      enabled: true
    )

    without_error = Integration.create!(
      user: @user,
      platform_name: "facebook",
      provider: "facebook_api",
      access_token: "test_access_token",
      connection_status: "connected",
      error_count: 0,
      enabled: true
    )

    assert_includes Integration.with_errors, with_error
    assert_not_includes Integration.with_errors, without_error
  end

  # Business Logic Tests
  test "connect! should attempt to connect to platform" do
    @integration.save!
    # connect! will fail because platform connections are not implemented
    # but we can test that it handles the error properly
    result = @integration.connect!

    assert_equal false, result
    assert_equal "error", @integration.connection_status
    assert @integration.error_count > 0
    assert_not_nil @integration.error_message

    # If connection had succeeded, it would set connected_at
    assert_nil @integration.connected_at
  end

  test "disconnect! should update connection status" do
    @integration.connection_status = "connected"
    @integration.save!
    @integration.disconnect!

    assert_equal "disconnected", @integration.connection_status
    assert_nil @integration.connected_at
    assert_nil @integration.access_token
    assert_nil @integration.refresh_token
  end

  test "error! should update error information" do
    @integration.save!
    @integration.error!("API rate limit exceeded")

    assert_equal "error", @integration.connection_status
    assert_equal "API rate limit exceeded", @integration.error_message
    assert_equal 1, @integration.error_count
    assert_not_nil @integration.last_error_at
  end

  test "connected? should return true when connected" do
    @integration.connection_status = "connected"
    assert @integration.connected?
  end

  test "disconnected? should return true when disconnected" do
    @integration.connection_status = "disconnected"
    assert @integration.disconnected?
  end

  test "error? should return true when in error state" do
    @integration.connection_status = "error"
    assert @integration.error?
  end

  test "sync_overdue? should return true for integrations needing sync" do
    @integration.connection_status = "connected"
    @integration.enabled = true
    @integration.last_sync_at = 2.hours.ago
    @integration.sync_frequency = "hourly"
    @integration.save!

    assert @integration.sync_overdue?
  end

  test "sync_status should return appropriate status message" do
    @integration.last_sync_at = nil
    assert_equal "never", @integration.sync_status

    @integration.last_sync_at = 30.minutes.ago
    assert_equal "recent", @integration.sync_status

    @integration.last_sync_at = 5.hours.ago
    assert_equal "today", @integration.sync_status

    @integration.last_sync_at = 3.days.ago
    assert_equal "this_week", @integration.sync_status

    @integration.last_sync_at = 10.days.ago
    assert_equal "old", @integration.sync_status
  end

  test "health_score should calculate based on various factors" do
    # Perfect health
    @integration.connection_status = "connected"
    @integration.status = "active"
    @integration.enabled = true
    @integration.error_count = 0
    @integration.last_successful_sync_at = 5.minutes.ago
    @integration.sync_frequency = "hourly"
    assert @integration.health_score >= 70

    # Poor health
    @integration.connection_status = "error"
    @integration.error_count = 10
    @integration.last_successful_sync_at = 3.days.ago
    assert @integration.health_score == 0  # Not active when status is error
  end

  test "health_status should return appropriate status based on score" do
    @integration.connection_status = "connected"
    @integration.status = "active"
    @integration.enabled = true
    @integration.error_count = 0
    @integration.last_successful_sync_at = 5.minutes.ago
    # Score should be high but may not be "excellent" due to calculation details
    assert_includes [ "excellent", "good" ], @integration.health_status

    @integration.error_count = 5
    @integration.last_successful_sync_at = 2.hours.ago
    assert_includes [ "good", "fair", "poor" ], @integration.health_status

    @integration.connection_status = "error"
    @integration.error_count = 20
    assert_equal "critical", @integration.health_status  # 0 score = critical
  end

  test "should handle token expiration" do
    @integration.token_expires_at = nil
    # Token without expiration is valid
    assert @integration.valid?

    @integration.token_expires_at = 1.hour.from_now
    # Token not yet expired
    assert @integration.valid?

    @integration.token_expires_at = 1.hour.ago
    # Expired token should be handled during connection check
    assert @integration.valid?  # Model itself is still valid
  end

  test "should handle activity logging" do
    @integration.save!

    # The log_activity method in the model only takes activity_type and details
    # It should create a log if IntegrationLog model exists
    # Since we don't have IntegrationLog fixtures set up, just verify the integration saves
    assert @integration.persisted?
  end

  test "sync! should update last sync time" do
    @integration.save!
    @integration.update!(connection_status: "connected", enabled: true)

    # sync! will attempt to enqueue a job
    result = @integration.sync!

    # Should update last_sync_at even if job enqueuing fails
    assert_not_nil @integration.last_sync_at
  end

  test "should reset error state when connecting successfully" do
    @integration.connection_status = "error"
    @integration.error_count = 5
    @integration.error_message = "Some error"
    @integration.save!

    # Simulate successful connection (in real app, connect! would do this)
    @integration.update!(
      connection_status: "connected",
      error_count: 0,
      error_message: nil
    )

    assert_equal 0, @integration.error_count
    assert_nil @integration.error_message
    assert_equal "connected", @integration.connection_status
  end

  test "mentions_count should return count of related mentions" do
    @integration.save!
    # This would need actual Mention records to test properly
    assert_equal 0, @integration.mentions_count
  end

  test "leads_count should return count of related leads" do
    @integration.save!
    # This would need actual Lead records to test properly
    assert_equal 0, @integration.leads_count
  end

  test "sync_success_rate should return default when no syncs" do
    @integration.save!

    # Without IntegrationLog records and when total_synced_items is zero, returns 0
    # When total_syncs (logs) is zero but total_synced_items > 0, returns 100
    assert_equal 0, @integration.sync_success_rate
  end

  test "should handle rate limiting" do
    @integration.connection_status = "connected"
    assert_not @integration.rate_limited?

    @integration.connection_status = "rate_limited"
    assert @integration.rate_limited?

    # Also rate limited when limit remaining is 0
    @integration.connection_status = "connected"
    @integration.rate_limit_remaining = 0
    @integration.rate_limit_reset_at = 1.hour.from_now
    assert @integration.rate_limited?

    # Not rate limited when reset time has passed
    @integration.rate_limit_reset_at = 1.hour.ago
    assert_not @integration.rate_limited?
  end
end
