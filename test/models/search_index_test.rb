require "test_helper"

class SearchIndexTest < ActiveSupport::TestCase
  def setup
    @search_index = search_indices(:one)
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @search_index.valid?
  end

  test "should require name" do
    @search_index.name = nil
    assert_not @search_index.valid?
    assert_includes @search_index.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    duplicate_index = @search_index.dup
    @search_index.save
    assert_not duplicate_index.valid?
    assert_includes duplicate_index.errors[:name], "has already been taken"
  end

  test "should require index_type" do
    @search_index.index_type = nil
    assert_not @search_index.valid?
    assert_includes @search_index.errors[:index_type], "can't be blank"
  end

  test "should validate index_type is included in list" do
    @search_index.index_type = "invalid_type"
    assert_not @search_index.valid?
    assert_includes @search_index.errors[:index_type], "is not included in the list"
  end

  test "should accept valid index types" do
    %w[mentions leads analysis_results keywords users].each do |type|
      @search_index.index_type = type
      assert @search_index.valid?, "#{type} should be valid"
    end
  end

  test "should validate documents_count is non-negative" do
    @search_index.documents_count = -1
    assert_not @search_index.valid?
    assert_includes @search_index.errors[:documents_count], "must be greater than or equal to 0"

    @search_index.documents_count = 0
    assert @search_index.valid?

    @search_index.documents_count = 100
    assert @search_index.valid?
  end

  # AASM State Tests
  test "should have initial state as pending" do
    new_index = SearchIndex.new(
      name: "test_index",
      index_type: "mentions"
    )
    assert_equal "pending", new_index.status
    assert new_index.pending?
  end

  test "should transition from pending to creating" do
    @search_index.status = "pending"
    assert @search_index.may_start_creation?
    
    @search_index.start_creation!
    assert_equal "creating", @search_index.status
    assert @search_index.creating?
  end

  test "should transition from creating to active" do
    @search_index.status = "creating"
    assert @search_index.may_activate?
    
    @search_index.activate!
    assert_equal "active", @search_index.status
    assert @search_index.active?
  end

  test "should transition from active to inactive" do
    @search_index.status = "active"
    assert @search_index.may_deactivate?
    
    @search_index.deactivate!
    assert_equal "inactive", @search_index.status
    assert @search_index.inactive?
  end

  test "should transition from inactive to active" do
    @search_index.status = "inactive"
    assert @search_index.may_reactivate?
    
    @search_index.reactivate!
    assert_equal "active", @search_index.status
    assert @search_index.active?
  end

  test "should transition to error state from creating" do
    @search_index.status = "creating"
    assert @search_index.may_mark_failed?
    
    @search_index.mark_failed!
    assert_equal "error", @search_index.status
    assert @search_index.error?
  end

  test "should not allow invalid state transitions" do
    @search_index.status = "pending"
    assert_not @search_index.may_activate?
    
    assert_raises(AASM::InvalidTransition) do
      @search_index.activate!
    end
  end

  # Scope Tests
  test "active scope should return only active indices" do
    active_indices = SearchIndex.active
    active_indices.each do |index|
      assert_equal "active", index.status
    end
  end

  test "by_type scope should filter by index_type" do
    mention_indices = SearchIndex.by_type("mentions")
    mention_indices.each do |index|
      assert_equal "mentions", index.index_type
    end
  end

  test "with_documents scope should return indices with documents" do
    SearchIndex.destroy_all
    with_docs = SearchIndex.create!(
      name: "with_docs",
      index_type: "mentions",
      documents_count: 10
    )
    without_docs = SearchIndex.create!(
      name: "without_docs",
      index_type: "leads",
      documents_count: 0
    )

    indices = SearchIndex.with_documents
    assert_includes indices, with_docs
    assert_not_includes indices, without_docs
  end

  test "stale scope should return indices not indexed recently" do
    SearchIndex.destroy_all
    fresh = SearchIndex.create!(
      name: "fresh",
      index_type: "mentions",
      last_indexed_at: 1.hour.ago
    )
    stale = SearchIndex.create!(
      name: "stale",
      index_type: "leads",
      last_indexed_at: 25.hours.ago
    )
    never_indexed = SearchIndex.create!(
      name: "never",
      index_type: "keywords",
      last_indexed_at: nil
    )

    stale_indices = SearchIndex.stale
    assert_not_includes stale_indices, fresh
    assert_includes stale_indices, stale
    assert_includes stale_indices, never_indexed
  end

  # Method Tests
  test "should return index_name correctly" do
    @search_index.name = "test_index_v1"
    assert_equal "test_index_v1_test", @search_index.index_name

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_equal "test_index_v1_production", @search_index.index_name
    end
  end

  test "should check if index needs refresh" do
    @search_index.last_indexed_at = nil
    assert @search_index.needs_refresh?

    @search_index.last_indexed_at = 2.days.ago
    assert @search_index.needs_refresh?

    @search_index.last_indexed_at = 1.hour.ago
    assert_not @search_index.needs_refresh?
  end

  test "should check if index is operational" do
    @search_index.status = "active"
    assert @search_index.operational?

    @search_index.status = "inactive"
    assert_not @search_index.operational?

    @search_index.status = "error"
    assert_not @search_index.operational?
  end

  test "should update indexed timestamp" do
    original_time = @search_index.last_indexed_at
    @search_index.update_indexed!
    
    assert_not_equal original_time, @search_index.last_indexed_at
    assert @search_index.last_indexed_at > 1.second.ago
  end

  test "should increment document count" do
    original_count = @search_index.documents_count
    @search_index.increment_documents(5)
    
    assert_equal original_count + 5, @search_index.documents_count
  end

  test "should decrement document count" do
    @search_index.documents_count = 10
    @search_index.decrement_documents(3)
    
    assert_equal 7, @search_index.documents_count
  end

  test "should not allow negative document count when decrementing" do
    @search_index.documents_count = 2
    @search_index.decrement_documents(5)
    
    assert_equal 0, @search_index.documents_count
  end

  # JSON Field Tests
  test "should store and retrieve configuration as JSON" do
    config = {
      "settings" => {
        "number_of_shards" => 3,
        "number_of_replicas" => 1
      },
      "analysis" => {
        "analyzer" => {
          "custom_analyzer" => {
            "type" => "custom",
            "tokenizer" => "standard"
          }
        }
      }
    }
    @search_index.configuration = config
    @search_index.save!
    @search_index.reload

    assert_equal config, @search_index.configuration
    assert_equal 3, @search_index.configuration["settings"]["number_of_shards"]
  end

  test "should store and retrieve mapping as JSON" do
    mapping = {
      "properties" => {
        "title" => { "type" => "text" },
        "content" => { "type" => "text" },
        "created_at" => { "type" => "date" },
        "score" => { "type" => "float" }
      }
    }
    @search_index.mapping = mapping
    @search_index.save!
    @search_index.reload

    assert_equal mapping, @search_index.mapping
    assert_equal "text", @search_index.mapping["properties"]["title"]["type"]
  end

  # Default Values Tests
  test "should set default documents_count to 0" do
    new_index = SearchIndex.new(
      name: "test",
      index_type: "mentions"
    )
    assert_equal 0, new_index.documents_count
  end

  test "should initialize configuration as empty hash" do
    new_index = SearchIndex.new(
      name: "test",
      index_type: "mentions"
    )
    assert_equal({}, new_index.configuration)
  end

  test "should initialize mapping as empty hash" do
    new_index = SearchIndex.new(
      name: "test",
      index_type: "mentions"
    )
    assert_equal({}, new_index.mapping)
  end

  # Edge Cases
  test "should handle nil JSON fields gracefully" do
    @search_index.configuration = nil
    @search_index.mapping = nil
    
    assert @search_index.valid?
    assert @search_index.save
  end
end
