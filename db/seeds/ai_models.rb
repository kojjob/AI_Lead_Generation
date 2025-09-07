# Create default AI models for the system
puts "Creating default AI models..."

# OpenAI Models
AiModel.find_or_create_by(name: 'gpt-4-turbo-preview', provider: 'openai') do |model|
  model.model_type = 'text_classification'
  model.version = '2024-01'
  model.description = 'Advanced text classification with GPT-4'
  model.enabled = true
  model.priority = 100
  model.configuration = {
    temperature: 0.3,
    max_tokens: 2000,
    top_p: 0.9
  }
  model.capabilities = { multi_label: true, binary: true, hierarchical: true }
  model.pricing = { per_request: 0.03, per_token: 0.00003 }
end

AiModel.find_or_create_by(name: 'gpt-4-turbo-preview', provider: 'openai', model_type: 'lead_scoring') do |model|
  model.version = '2024-01'
  model.description = 'Intelligent lead scoring with GPT-4'
  model.enabled = true
  model.priority = 100
  model.configuration = {
    temperature: 0.2,
    max_tokens: 1500
  }
  model.capabilities = { quality: true, urgency: true, fit_score: true }
  model.pricing = { per_request: 0.03, per_token: 0.00003 }
end

AiModel.find_or_create_by(name: 'gpt-3.5-turbo', provider: 'openai') do |model|
  model.model_type = 'sentiment_analysis'
  model.version = '0613'
  model.description = 'Fast sentiment analysis with GPT-3.5'
  model.enabled = true
  model.priority = 80
  model.configuration = {
    temperature: 0.3,
    max_tokens: 1000
  }
  model.capabilities = { polarity: true, emotion: true, aspect_based: false }
  model.pricing = { per_request: 0.002, per_token: 0.000002 }
end

AiModel.find_or_create_by(name: 'text-embedding-3-small', provider: 'openai') do |model|
  model.model_type = 'embedding'
  model.version = '3'
  model.description = 'Fast and efficient text embeddings'
  model.enabled = true
  model.priority = 90
  model.configuration = {
    dimensions: 1536,
    encoding_format: 'float'
  }
  model.capabilities = { text_embedding: true, semantic_search: true, clustering: true }
  model.pricing = { per_token: 0.00002 }
end

# Anthropic Models
AiModel.find_or_create_by(name: 'claude-3-opus-20240229', provider: 'anthropic') do |model|
  model.model_type = 'text_classification'
  model.version = '20240229'
  model.description = 'Advanced classification with Claude 3 Opus'
  model.enabled = false
  model.priority = 95
  model.configuration = {
    max_tokens: 2000,
    temperature: 0.3
  }
  model.capabilities = { multi_label: true, binary: true, hierarchical: true }
  model.pricing = { per_request: 0.015, per_token: 0.000015 }
end

AiModel.find_or_create_by(name: 'claude-3-sonnet-20240229', provider: 'anthropic') do |model|
  model.model_type = 'sentiment_analysis'
  model.version = '20240229'
  model.description = 'Balanced sentiment analysis with Claude 3 Sonnet'
  model.enabled = false
  model.priority = 85
  model.configuration = {
    max_tokens: 1000,
    temperature: 0.3
  }
  model.capabilities = { polarity: true, emotion: true, aspect_based: true }
  model.pricing = { per_request: 0.003, per_token: 0.000003 }
end

# Google Gemini Models
AiModel.find_or_create_by(name: 'gemini-pro', provider: 'google_gemini') do |model|
  model.model_type = 'entity_extraction'
  model.version = '1.0'
  model.description = 'Entity extraction with Gemini Pro'
  model.enabled = false
  model.priority = 85
  model.configuration = {
    candidate_count: 1,
    temperature: 0.2
  }
  model.capabilities = { named_entities: true, keywords: true, topics: true }
  model.pricing = { per_request: 0.01, per_token: 0.00001 }
end

# Cohere Models
AiModel.find_or_create_by(name: 'command', provider: 'cohere') do |model|
  model.model_type = 'summarization'
  model.version = 'latest'
  model.description = 'Text summarization with Cohere Command'
  model.enabled = false
  model.priority = 75
  model.configuration = {
    max_tokens: 500,
    temperature: 0.3
  }
  model.capabilities = { extractive: true, abstractive: true }
  model.pricing = { per_request: 0.01, per_token: 0.00001 }
end

# Ollama Models (Local)
AiModel.find_or_create_by(name: 'llama2', provider: 'ollama') do |model|
  model.model_type = 'text_classification'
  model.version = 'latest'
  model.description = 'Local classification with Llama 2'
  model.enabled = false
  model.priority = 60
  model.configuration = {
    temperature: 0.3,
    num_predict: 1000
  }
  model.capabilities = { multi_label: true, binary: true }
  model.pricing = { per_request: 0, per_token: 0 }
end

AiModel.find_or_create_by(name: 'mistral', provider: 'ollama') do |model|
  model.model_type = 'lead_scoring'
  model.version = 'latest'
  model.description = 'Local lead scoring with Mistral'
  model.enabled = false
  model.priority = 65
  model.configuration = {
    temperature: 0.2,
    num_predict: 500
  }
  model.capabilities = { quality: true, urgency: true }
  model.pricing = { per_request: 0, per_token: 0 }
end

puts "Created #{AiModel.count} AI models"

# Create default search indices
puts "Creating default search indices..."

SearchIndex.find_or_create_by(name: 'mentions_index') do |index|
  index.index_type = 'mentions'
  index.configuration = {
    shards: 2,
    replicas: 1,
    refresh_interval: '1s'
  }
  index.mapping = {
    properties: {
      content: { type: 'text', analyzer: 'standard' },
      source_url: { type: 'keyword' },
      platform: { type: 'keyword' },
      author: { type: 'keyword' },
      created_at: { type: 'date' },
      sentiment_score: { type: 'float' },
      relevance_score: { type: 'float' },
      keyword_id: { type: 'integer' },
      user_id: { type: 'integer' }
    }
  }
  index.status = 'pending'
  index.auto_sync = true
  index.sync_frequency = 3600
end

SearchIndex.find_or_create_by(name: 'leads_index') do |index|
  index.index_type = 'leads'
  index.configuration = {
    shards: 1,
    replicas: 1,
    refresh_interval: '5s'
  }
  index.mapping = {
    properties: {
      name: { type: 'text' },
      email: { type: 'keyword' },
      company: { type: 'text' },
      score: { type: 'float' },
      status: { type: 'keyword' },
      source: { type: 'keyword' },
      created_at: { type: 'date' },
      updated_at: { type: 'date' }
    }
  }
  index.status = 'pending'
  index.auto_sync = true
  index.sync_frequency = 1800
end

SearchIndex.find_or_create_by(name: 'analysis_results_index') do |index|
  index.index_type = 'analysis_results'
  index.configuration = {
    shards: 2,
    replicas: 1,
    refresh_interval: '10s'
  }
  index.mapping = {
    properties: {
      summary: { type: 'text', analyzer: 'english' },
      sentiment: { type: 'keyword' },
      entities: { type: 'nested' },
      topics: { type: 'keyword' },
      intent: { type: 'keyword' },
      relevance_score: { type: 'float' },
      confidence_score: { type: 'float' },
      analyzed_at: { type: 'date' }
    }
  }
  index.status = 'pending'
  index.auto_sync = true
  index.sync_frequency = 7200
end

puts "Created #{SearchIndex.count} search indices"
puts "AI models and search indices seeding completed!"