require "test_helper"

class DashboardServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @service = DashboardService.new(@user)
  end

  test "dashboard_data returns expected structure" do
    data = @service.dashboard_data

    assert_includes data, :stats
    assert_includes data, :recent_leads
    assert_includes data, :recent_mentions
    assert_includes data, :keyword_performance

    # Check stats structure
    assert_includes data[:stats], :total_keywords
    assert_includes data[:stats], :total_leads
    assert_includes data[:stats], :new_leads_today
    assert_includes data[:stats], :active_integrations
  end

  test "analytics_data returns expected structure" do
    data = @service.analytics_data

    assert_includes data, :stats
    assert_includes data, :leads_chart_data
    assert_includes data, :conversion_chart_data
    assert_includes data, :platform_breakdown
    assert_includes data, :top_keywords
    assert_includes data, :recent_activity

    # Check stats structure for analytics
    assert_includes data[:stats], :total_keywords
    assert_includes data[:stats], :active_keywords
    assert_includes data[:stats], :total_mentions
    assert_includes data[:stats], :total_leads
    assert_includes data[:stats], :qualified_leads
    assert_includes data[:stats], :conversion_rate
  end

  test "data is cached" do
    # First call should cache the data
    Rails.cache.clear
    data1 = @service.dashboard_data

    # Modify the user's data
    @user.keywords.create!(keyword: "test_keyword")

    # Second call should return cached data (not reflecting the new keyword)
    data2 = @service.dashboard_data

    assert_equal data1[:stats][:total_keywords], data2[:stats][:total_keywords]
  end

  test "conversion rate calculation handles zero mentions" do
    # Clear all mentions
    Mention.joins(:keyword).where(keywords: { user_id: @user.id }).destroy_all

    data = @service.analytics_data

    assert_equal 0, data[:stats][:conversion_rate]
  end
end
