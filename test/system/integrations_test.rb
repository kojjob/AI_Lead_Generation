require "application_system_test_case"

class IntegrationsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user

    @integration = Integration.create!(
      user: @user,
      platform_name: "twitter",
      provider: "twitter_api_v2",
      api_key: "test_api_key",
      api_secret: "test_api_secret",
      connection_status: "connected",
      enabled: true,
      sync_frequency: "hourly"
    )
  end

  test "visiting the integrations index" do
    visit integrations_url

    assert_selector "h1", text: "Platform Integrations"
    assert_text "Twitter"
    assert_text "Connected"
  end

  test "visiting the integration health check dashboard" do
    visit health_check_integrations_url

    assert_selector "h1", text: "Integration Health Dashboard"
    assert_text "Overall System Health"
    assert_text "Integration Health Details"
  end

  test "creating a new integration" do
    visit integrations_url
    click_on "Add Integration"

    assert_selector "h1", text: "Connect Your Platform"

    select "Linkedin", from: "Platform"
    fill_in "API Provider", with: "linkedin_api"
    fill_in "API Key / Client ID", with: "new_api_key"
    fill_in "API Secret / Client Secret", with: "new_api_secret"
    select "Daily", from: "Sync Frequency"
    check "Enable automatic syncing"

    accept_confirm do
      click_on "Create Integration"
    end

    assert_text "Integration was successfully created"
    assert_selector "h1", text: "Platform Integrations"
  end

  test "viewing an integration" do
    visit integration_url(@integration)

    assert_selector "h1", text: "Twitter"
    assert_text "Integration Status"
    assert_text "Recent Activity"
    assert_text "Statistics"
    assert_selector "span", text: "Connected"
  end

  test "editing an integration" do
    visit integration_url(@integration)
    click_on "Edit"

    assert_selector "h1", text: "Edit Twitter Integration"

    fill_in "Api secret", with: "updated_api_secret"
    select "Hourly", from: "Sync frequency"
    uncheck "Enable automatic syncing"

    click_on "Update Integration"

    assert_text "Integration was successfully updated"
    assert_selector "h1", text: "Twitter"
  end

  test "viewing integration logs" do
    # Create some sample logs
    IntegrationLog.create!(
      integration: @integration,
      activity_type: "sync_completed",
      details: "Successfully synced 10 mentions",
      performed_at: Time.current
    )

    visit logs_integration_url(@integration)

    assert_selector "h1", text: "Activity Logs - Twitter"
    assert_text "Successfully synced 10 mentions"
    assert_text "Sync"
    assert_text "Success"
  end

  test "disconnecting an integration" do
    visit integration_url(@integration)

    assert_selector "span", text: "Connected"

    click_on "Disconnect"

    assert_text "Disconnected from platform"
    visit integration_url(@integration)
    assert_selector "span", text: "Disconnected"
  end

  test "syncing an integration" do
    visit integration_url(@integration)

    click_on "Sync Now"

    assert_text "Sync initiated"
  end

  test "deleting an integration" do
    visit integration_url(@integration)

    accept_confirm do
      click_on "Delete Integration"
    end

    assert_text "Integration was successfully removed"
    assert_selector "h1", text: "Platform Integrations"
    assert_no_text "Twitter"
  end

  test "health summary cards display correctly" do
    # Create integrations with different statuses
    Integration.create!(
      user: @user,
      platform_name: "facebook",
      provider: "facebook_api",
      access_token: "test_facebook_access_token",
      connection_status: "error",
      error_count: 5,
      enabled: true
    )

    Integration.create!(
      user: @user,
      platform_name: "linkedin",
      provider: "linkedin_api",
      api_key: "test_linkedin_api_key",
      api_secret: "test_linkedin_api_secret",
      connection_status: "disconnected",
      enabled: false
    )

    visit integrations_url

    # Check health summary cards
    assert_text "Total Integrations"
    assert_text "3" # twitter, facebook, linkedin
    assert_text "Connected"
    assert_text "1" # only twitter
    assert_text "With Errors"
    assert_text "1" # facebook
  end

  test "integration form validation" do
    visit new_integration_url

    # Try to submit without required fields
    accept_confirm do
      click_on "Create Integration"
    end

    assert_text "error"
    assert_selector "h1", text: "Connect Your Platform" # Still on the form page
  end

  test "available platforms shown on new integration page" do
    visit new_integration_url

    assert_text "Choose Your Platform"
    # Should show platforms not yet connected
    assert_text "Monitor tweets, mentions, and hashtags in real-time"
  end

  test "error message display on integration page" do
    @integration.update!(
      connection_status: "error",
      error_message: "API rate limit exceeded",
      last_error_at: Time.current
    )

    visit integration_url(@integration)

    assert_text "Last Error"
    assert_text "API rate limit exceeded"
  end

  test "integration statistics display" do
    # Update integration with some statistics
    @integration.update!(
      total_synced_items: 150
    )

    visit integration_url(@integration)

    assert_text "Total Mentions"
    assert_text "0" # No mentions created in test
    assert_text "Generated Leads" 
    assert_text "0" # No leads created in test
    assert_text "Total Synced Items"
    assert_text "150"
  end
end
