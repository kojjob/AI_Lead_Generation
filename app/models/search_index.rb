class SearchIndex < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :index_type, presence: true

  scope :active, -> { where(status: 'active') }
  scope :auto_sync_enabled, -> { where(auto_sync: true) }
  scope :needs_sync, -> { where('last_synced_at < ?', 1.hour.ago).or(where(last_synced_at: nil)) }

  INDEX_TYPES = %w[mentions leads analysis_results keywords integrations].freeze
  STATUSES = %w[pending creating active inactive error].freeze

  include AASM

  aasm column: :status do
    state :pending, initial: true
    state :creating
    state :active
    state :inactive
    state :error

    event :start_creation do
      transitions from: :pending, to: :creating
    end

    event :activate do
      transitions from: :creating, to: :active
      after do
        update(last_indexed_at: Time.current)
      end
    end

    event :deactivate do
      transitions from: :active, to: :inactive
    end

    event :mark_error do
      transitions from: [:pending, :creating, :active, :inactive], to: :error
    end
  end

  def self.default_indices
    [
      {
        name: 'mentions_index',
        index_type: 'mentions',
        configuration: {
          shards: 2,
          replicas: 1,
          refresh_interval: '1s'
        },
        mapping: {
          properties: {
            content: { type: 'text', analyzer: 'standard' },
            source_url: { type: 'keyword' },
            platform: { type: 'keyword' },
            author: { type: 'keyword' },
            created_at: { type: 'date' },
            sentiment_score: { type: 'float' },
            relevance_score: { type: 'float' },
            keyword_id: { type: 'integer' },
            user_id: { type: 'integer' },
            location: { type: 'geo_point' },
            tags: { type: 'keyword' },
            embeddings: { type: 'dense_vector', dims: 1536 }
          }
        }
      },
      {
        name: 'leads_index',
        index_type: 'leads',
        configuration: {
          shards: 1,
          replicas: 1,
          refresh_interval: '5s'
        },
        mapping: {
          properties: {
            name: { type: 'text' },
            email: { type: 'keyword' },
            company: { type: 'text' },
            score: { type: 'float' },
            status: { type: 'keyword' },
            source: { type: 'keyword' },
            tags: { type: 'keyword' },
            created_at: { type: 'date' },
            updated_at: { type: 'date' },
            custom_fields: { type: 'object', enabled: false },
            interaction_count: { type: 'integer' },
            last_interaction: { type: 'date' }
          }
        }
      },
      {
        name: 'analysis_results_index',
        index_type: 'analysis_results',
        configuration: {
          shards: 2,
          replicas: 1,
          refresh_interval: '10s'
        },
        mapping: {
          properties: {
            summary: { type: 'text', analyzer: 'english' },
            sentiment: { type: 'keyword' },
            entities: { type: 'nested' },
            topics: { type: 'keyword' },
            intent: { type: 'keyword' },
            relevance_score: { type: 'float' },
            confidence_score: { type: 'float' },
            analyzed_at: { type: 'date' },
            ai_model: { type: 'keyword' },
            processing_time: { type: 'float' }
          }
        }
      }
    ]
  end

  def self.create_defaults!
    default_indices.each do |attrs|
      find_or_create_by(name: attrs[:name]) do |index|
        index.assign_attributes(attrs)
      end
    end
  end

  def elasticsearch_client
    @elasticsearch_client ||= Elasticsearch::Client.new(
      host: ENV.fetch('ELASTICSEARCH_HOST', 'localhost:9200'),
      log: Rails.env.development?
    )
  end

  def create_index!
    return false if index_exists?

    start_creation!
    
    elasticsearch_client.indices.create(
      index: elasticsearch_index_name || name,
      body: {
        settings: configuration,
        mappings: mapping
      }
    )
    
    activate!
    true
  rescue => e
    mark_error!
    update(statistics: { error: e.message })
    false
  end

  def delete_index!
    return false unless index_exists?

    elasticsearch_client.indices.delete(index: elasticsearch_index_name || name)
    deactivate!
    true
  rescue => e
    update(statistics: { error: e.message })
    false
  end

  def index_exists?
    elasticsearch_client.indices.exists?(index: elasticsearch_index_name || name)
  end

  def refresh!
    elasticsearch_client.indices.refresh(index: elasticsearch_index_name || name)
  end

  def document_count
    response = elasticsearch_client.count(index: elasticsearch_index_name || name)
    response['count']
  rescue
    0
  end

  def index_stats
    response = elasticsearch_client.indices.stats(index: elasticsearch_index_name || name)
    response['indices'][elasticsearch_index_name || name]
  rescue
    {}
  end

  def sync!
    return unless auto_sync? && needs_sync?

    case index_type
    when 'mentions'
      sync_mentions
    when 'leads'
      sync_leads
    when 'analysis_results'
      sync_analysis_results
    end

    update(
      last_synced_at: Time.current,
      documents_count: document_count,
      statistics: index_stats
    )
  end

  def search(query, options = {})
    body = build_search_body(query, options)
    
    response = elasticsearch_client.search(
      index: elasticsearch_index_name || name,
      body: body
    )
    
    {
      total: response['hits']['total']['value'],
      hits: response['hits']['hits'],
      aggregations: response['aggregations']
    }
  end

  private

  def needs_sync?
    last_synced_at.nil? || last_synced_at < sync_frequency.seconds.ago
  end

  def build_search_body(query, options)
    body = {
      query: {
        multi_match: {
          query: query,
          fields: search_fields_for_type,
          type: 'best_fields'
        }
      }
    }

    if options[:filters].present?
      body[:query] = {
        bool: {
          must: body[:query],
          filter: build_filters(options[:filters])
        }
      }
    end

    body[:size] = options[:size] || 10
    body[:from] = options[:from] || 0
    body[:sort] = options[:sort] if options[:sort].present?
    body[:aggs] = options[:aggregations] if options[:aggregations].present?

    body
  end

  def search_fields_for_type
    case index_type
    when 'mentions'
      %w[content^2 author platform tags]
    when 'leads'
      %w[name^2 email company tags]
    when 'analysis_results'
      %w[summary^2 topics entities.name]
    else
      %w[_all]
    end
  end

  def build_filters(filters)
    filters.map do |field, value|
      if value.is_a?(Range)
        { range: { field => { gte: value.min, lte: value.max } } }
      elsif value.is_a?(Array)
        { terms: { field => value } }
      else
        { term: { field => value } }
      end
    end
  end

  def sync_mentions
    Mention.find_in_batches(batch_size: 1000) do |batch|
      bulk_index_documents(
        batch.map { |mention| format_mention_for_index(mention) }
      )
    end
  end

  def sync_leads
    Lead.find_in_batches(batch_size: 1000) do |batch|
      bulk_index_documents(
        batch.map { |lead| format_lead_for_index(lead) }
      )
    end
  end

  def sync_analysis_results
    AnalysisResult.find_in_batches(batch_size: 1000) do |batch|
      bulk_index_documents(
        batch.map { |result| format_analysis_for_index(result) }
      )
    end
  end

  def bulk_index_documents(documents)
    return if documents.empty?

    body = documents.flat_map do |doc|
      [
        { index: { _index: elasticsearch_index_name || name, _id: doc[:id] } },
        doc
      ]
    end

    elasticsearch_client.bulk(body: body)
  end

  def format_mention_for_index(mention)
    {
      id: mention.id,
      content: mention.content,
      source_url: mention.source_url,
      platform: mention.platform,
      author: mention.author,
      created_at: mention.created_at,
      keyword_id: mention.keyword_id,
      user_id: mention.keyword.user_id,
      tags: mention.tags
    }
  end

  def format_lead_for_index(lead)
    {
      id: lead.id,
      name: lead.name,
      email: lead.email,
      company: lead.company,
      score: lead.score,
      status: lead.status,
      source: lead.source,
      tags: lead.tags,
      created_at: lead.created_at,
      updated_at: lead.updated_at
    }
  end

  def format_analysis_for_index(result)
    {
      id: result.id,
      summary: result.summary,
      sentiment: result.sentiment,
      entities: result.entities,
      topics: result.topics,
      relevance_score: result.relevance_score,
      confidence_score: result.confidence_score,
      analyzed_at: result.created_at
    }
  end
end