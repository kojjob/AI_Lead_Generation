require "test_helper"

class MentionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get mentions_index_url
    assert_response :success
  end

  test "should get show" do
    get mentions_show_url
    assert_response :success
  end
end
