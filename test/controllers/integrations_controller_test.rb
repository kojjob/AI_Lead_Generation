require "test_helper"

class IntegrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    @integration = Integration.create!(
      user: @user,
      provider: "slack_provider",
      platform_name: "slack",
      connection_status: "connected",
      sync_frequency: "hourly"
    )
  end

  test "should get index" do
    get integrations_url
    assert_response :success
  end

  test "should get new" do
    get new_integration_url
    assert_response :success
  end

  test "should create integration" do
    assert_difference("Integration.count") do
      post integrations_url, params: {
        integration: {
          provider: "discord_provider_new",
          platform_name: "discord",
          webhook_url: "https://discord.com/webhook/test",
          sync_frequency: "hourly"
        }
      }
    end
    assert_redirected_to integrations_url
  end

  test "should show integration" do
    get integration_url(@integration)
    assert_response :success
  end

  test "should get edit" do
    get edit_integration_url(@integration)
    assert_response :success
  end

  test "should update integration" do
    patch integration_url(@integration), params: {
      integration: {
        sync_frequency: "daily"
      }
    }
    assert_redirected_to integration_url(@integration)
  end

  test "should destroy integration" do
    assert_difference("Integration.count", -1) do
      delete integration_url(@integration)
    end
    assert_redirected_to integrations_url
  end
end
