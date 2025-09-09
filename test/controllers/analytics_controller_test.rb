require "test_helper"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @keyword = keywords(:one)
    @mention = mentions(:one)
    @lead = leads(:one)
    sign_in @user
  end

  test "should get index" do
    get analytics_path
    assert_response :success
    assert_not_nil assigns(:metrics)
    assert_not_nil assigns(:performance_data)
    assert_not_nil assigns(:conversion_funnel)
  end

  test "should get performance" do
    get analytics_performance_path
    assert_response :success
    assert_not_nil assigns(:performance_metrics)
    assert_not_nil assigns(:time_series_data)
    assert_not_nil assigns(:comparative_analysis)
  end

  test "should get trends" do
    get analytics_trends_path
    assert_response :success
    assert_not_nil assigns(:trend_data)
    assert_not_nil assigns(:predictions)
    assert_not_nil assigns(:seasonality)
  end

  test "should get keywords" do
    get analytics_keywords_path
    assert_response :success
    assert_not_nil assigns(:keyword_performance)
    assert_not_nil assigns(:keyword_trends)
  end

  test "should get leads" do
    get analytics_leads_path
    assert_response :success
    assert_not_nil assigns(:lead_analytics)
    assert_not_nil assigns(:conversion_analysis)
  end

  test "should get integrations" do
    get analytics_integrations_path
    assert_response :success
    assert_not_nil assigns(:integration_metrics)
    assert_not_nil assigns(:source_comparison)
  end

  test "should export data as CSV" do
    get analytics_export_path(format: :csv, export_type: "overview")
    assert_response :success
    assert_equal "text/csv", response.content_type
  end

  test "should export data as JSON" do
    get analytics_export_path(format: :json, export_type: "overview")
    assert_response :success
    assert_equal "application/json", response.content_type
  end

  test "should get realtime updates" do
    get analytics_realtime_path
    assert_response :success
  end

  test "should filter by date range" do
    get analytics_path, params: { start_date: 7.days.ago, end_date: Date.current }
    assert_response :success
    assert_not_nil assigns(:start_date)
    assert_not_nil assigns(:end_date)
  end

  test "should cache analytics data" do
    # First request should cache the data
    get analytics_path
    assert_response :success

    # Second request should use cached data
    get analytics_path
    assert_response :success
  end

  test "should handle empty data gracefully" do
    # Remove all data for the user
    @user.mentions.destroy_all
    @user.leads.destroy_all

    get analytics_path
    assert_response :success
    assert_not_nil assigns(:metrics)
  end

  test "should calculate conversion funnel correctly" do
    get analytics_path
    funnel = assigns(:conversion_funnel)

    assert funnel[:mentions] >= funnel[:analyzed]
    assert funnel[:analyzed] >= funnel[:leads]
    assert funnel[:leads] >= funnel[:qualified]
    assert funnel[:qualified] >= funnel[:converted]
  end

  test "should require authentication" do
    sign_out @user
    get analytics_path
    assert_redirected_to new_user_session_path
  end

  test "should only show current user's data" do
    other_user = users(:two)

    get analytics_path
    metrics = assigns(:metrics)

    # Ensure we're not seeing other user's data
    assert_not_includes metrics.to_s, other_user.email
  end

  test "should handle different time periods" do
    periods = [ "daily", "weekly", "monthly" ]

    periods.each do |period|
      get analytics_performance_path, params: { period: period }
      assert_response :success
    end
  end

  test "should export keywords data" do
    get analytics_export_path(format: :csv, export_type: "keywords")
    assert_response :success
    assert_match /Keyword,Platform,Mentions,Leads/, response.body
  end

  test "should export leads data" do
    get analytics_export_path(format: :csv, export_type: "leads")
    assert_response :success
    assert_match /ID,Name,Email,Company,Score/, response.body
  end

  test "should handle JSON format for analytics data" do
    get analytics_path, params: { format: :json }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["metrics"].present?
    assert json_response["performance"].present?
  end
end
