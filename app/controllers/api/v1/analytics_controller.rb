# frozen_string_literal: true

module Api
  module V1
    class AnalyticsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_api_user!
      before_action :set_date_range
      before_action :set_pagination

      # GET /api/v1/analytics/overview
      def overview
        metrics = Rails.cache.fetch(api_cache_key("overview"), expires_in: 5.minutes) do
          {
            summary: calculate_summary_metrics,
            performance: calculate_performance_metrics,
            conversion_funnel: calculate_conversion_funnel,
            top_keywords: fetch_top_keywords,
            recent_leads: fetch_recent_leads
          }
        end

        render json: {
          status: "success",
          data: metrics,
          meta: {
            date_range: {
              start: @start_date,
              end: @end_date
            },
            generated_at: Time.current
          }
        }
      end

      # GET /api/v1/analytics/mentions
      def mentions
        mentions = current_api_user.mentions
                                  .includes(:keyword, :lead)
                                  .where(created_at: @date_range)
                                  .order(created_at: :desc)
                                  .page(@page)
                                  .per(@per_page)

        render json: {
          status: "success",
          data: mentions.map { |m| serialize_mention(m) },
          meta: pagination_meta(mentions)
        }
      end

      # GET /api/v1/analytics/leads
      def leads
        leads = current_api_user.leads
                               .includes(:mention, :keyword)
                               .where(created_at: @date_range)
                               .order(created_at: :desc)
                               .page(@page)
                               .per(@per_page)

        render json: {
          status: "success",
          data: leads.map { |l| serialize_lead(l) },
          meta: pagination_meta(leads)
        }
      end

      # GET /api/v1/analytics/keywords
      def keywords
        keywords_data = current_api_user.keywords.map do |keyword|
          mentions_count = keyword.mentions.where(created_at: @date_range).count
          leads_count = keyword.leads.where(created_at: @date_range).count

          {
            id: keyword.id,
            keyword: keyword.keyword,
            platform: keyword.platform,
            metrics: {
              mentions_count: mentions_count,
              leads_count: leads_count,
              conversion_rate: calculate_conversion_rate(mentions_count, leads_count),
              average_lead_score: keyword.leads.where(created_at: @date_range).average(:score)&.round(2)
            },
            created_at: keyword.created_at
          }
        end

        render json: {
          status: "success",
          data: keywords_data,
          meta: {
            total: keywords_data.size,
            date_range: {
              start: @start_date,
              end: @end_date
            }
          }
        }
      end

      # GET /api/v1/analytics/performance
      def performance
        performance_data = Rails.cache.fetch(api_cache_key("performance"), expires_in: 10.minutes) do
          {
            daily_metrics: fetch_daily_metrics,
            hourly_distribution: fetch_hourly_distribution,
            platform_breakdown: fetch_platform_breakdown,
            response_times: calculate_response_times,
            quality_scores: calculate_quality_scores
          }
        end

        render json: {
          status: "success",
          data: performance_data,
          meta: {
            date_range: {
              start: @start_date,
              end: @end_date
            },
            cached_at: Time.current
          }
        }
      end

      # GET /api/v1/analytics/trends
      def trends
        trends_data = {
          growth_metrics: calculate_growth_metrics,
          trending_keywords: fetch_trending_keywords,
          conversion_trends: calculate_conversion_trends,
          predictions: generate_simple_predictions
        }

        render json: {
          status: "success",
          data: trends_data,
          meta: {
            date_range: {
              start: @start_date,
              end: @end_date
            }
          }
        }
      end

      # POST /api/v1/analytics/export
      def export
        format = params[:format] || "json"
        data_type = params[:data_type] || "overview"

        export_data = compile_export_data(data_type)

        case format
        when "csv"
          send_data generate_csv(export_data),
                    filename: "analytics_#{data_type}_#{Date.current}.csv",
                    type: "text/csv"
        when "json"
          render json: {
            status: "success",
            data: export_data,
            meta: {
              export_type: data_type,
              exported_at: Time.current
            }
          }
        else
          render json: {
            status: "error",
            message: "Unsupported export format"
          }, status: :unprocessable_entity
        end
      end

      private

      def authenticate_api_user!
        authenticate_or_request_with_http_token do |token, options|
          @api_key = ApiKey.find_by(token: token)
          @current_api_user = @api_key&.user if @api_key&.active?
        end
      end

      def current_api_user
        @current_api_user
      end

      def set_date_range
        @start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago.to_date
        @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current
        @date_range = @start_date..@end_date
      rescue ArgumentError
        render json: {
          status: "error",
          message: "Invalid date format. Use YYYY-MM-DD"
        }, status: :bad_request
      end

      def set_pagination
        @page = (params[:page] || 1).to_i
        @per_page = [ (params[:per_page] || 25).to_i, 100 ].min
      end

      def api_cache_key(prefix)
        "api:analytics:#{prefix}:#{current_api_user.id}:#{@start_date}:#{@end_date}"
      end

      def calculate_summary_metrics
        {
          total_mentions: current_api_user.mentions.where(created_at: @date_range).count,
          total_leads: current_api_user.leads.where(created_at: @date_range).count,
          conversion_rate: calculate_overall_conversion_rate,
          average_lead_score: current_api_user.leads.where(created_at: @date_range).average(:score)&.round(2),
          active_keywords: current_api_user.keywords.active.count
        }
      end

      def calculate_performance_metrics
        mentions = current_api_user.mentions.where(created_at: @date_range)
        leads = current_api_user.leads.where(created_at: @date_range)

        {
          mentions_growth: calculate_growth_rate(mentions),
          leads_growth: calculate_growth_rate(leads),
          top_performing_keyword: fetch_top_performing_keyword,
          average_response_time: calculate_average_response_time
        }
      end

      def calculate_conversion_funnel
        total_mentions = current_api_user.mentions.where(created_at: @date_range).count
        analyzed = current_api_user.mentions.joins(:analysis_result).where(created_at: @date_range).count
        leads = current_api_user.leads.where(created_at: @date_range).count
        qualified = current_api_user.leads.where(created_at: @date_range, status: [ "qualified", "contacted", "converted" ]).count
        converted = current_api_user.leads.where(created_at: @date_range, status: "converted").count

        {
          mentions: total_mentions,
          analyzed: analyzed,
          leads: leads,
          qualified: qualified,
          converted: converted
        }
      end

      def fetch_top_keywords(limit = 5)
        current_api_user.keywords
                       .joins(:mentions)
                       .where(mentions: { created_at: @date_range })
                       .group("keywords.id", "keywords.keyword")
                       .order("COUNT(mentions.id) DESC")
                       .limit(limit)
                       .pluck("keywords.keyword", Arel.sql("COUNT(mentions.id) as count"))
                       .map { |k, c| { keyword: k, mentions: c } }
      end

      def fetch_recent_leads(limit = 10)
        current_api_user.leads
                       .where(created_at: @date_range)
                       .order(created_at: :desc)
                       .limit(limit)
                       .map { |l| serialize_lead(l) }
      end

      def serialize_mention(mention)
        {
          id: mention.id,
          content: mention.content,
          author_name: mention.author_name,
          platform: mention.platform,
          url: mention.url,
          keyword: mention.keyword.keyword,
          has_lead: mention.lead.present?,
          lead_score: mention.lead&.score,
          created_at: mention.created_at
        }
      end

      def serialize_lead(lead)
        {
          id: lead.id,
          author_name: lead.author_name,
          email: lead.email,
          company: lead.company,
          score: lead.score,
          status: lead.status,
          platform: lead.mention&.platform,
          keyword: lead.keyword&.keyword,
          created_at: lead.created_at
        }
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value,
          has_next: !collection.last_page?,
          has_previous: !collection.first_page?
        }
      end

      def calculate_conversion_rate(mentions_count, leads_count)
        return 0 if mentions_count.zero?
        ((leads_count.to_f / mentions_count) * 100).round(2)
      end

      def calculate_overall_conversion_rate
        mentions_count = current_api_user.mentions.where(created_at: @date_range).count
        leads_count = current_api_user.leads.where(created_at: @date_range).count
        calculate_conversion_rate(mentions_count, leads_count)
      end

      def calculate_growth_rate(collection)
        current_period = collection.where(created_at: @date_range).count
        previous_range = (@start_date - (@end_date - @start_date).days)..@start_date
        previous_period = collection.where(created_at: previous_range).count

        return 0 if previous_period.zero?
        (((current_period - previous_period).to_f / previous_period) * 100).round(2)
      end

      def fetch_top_performing_keyword
        keyword = current_api_user.keywords
                                 .joins(:leads)
                                 .where(leads: { created_at: @date_range })
                                 .group("keywords.id", "keywords.keyword")
                                 .order("COUNT(leads.id) DESC")
                                 .first

        return nil unless keyword

        {
          keyword: keyword.keyword,
          leads_generated: keyword.leads.where(created_at: @date_range).count
        }
      end

      def calculate_average_response_time
        # Placeholder - would need proper tracking of response times
        "< 5 minutes"
      end

      def fetch_daily_metrics
        (0..29).map do |days_ago|
          date = @end_date - days_ago.days
          {
            date: date,
            mentions: current_api_user.mentions.where(created_at: date.all_day).count,
            leads: current_api_user.leads.where(created_at: date.all_day).count
          }
        end.reverse
      end

      def fetch_hourly_distribution
        current_api_user.mentions
                       .where(created_at: @date_range)
                       .group_by_hour_of_day(:created_at)
                       .count
      end

      def fetch_platform_breakdown
        current_api_user.mentions
                       .where(created_at: @date_range)
                       .group(:platform)
                       .count
      end

      def calculate_response_times
        # Placeholder implementation
        {
          average: "5 minutes",
          median: "3 minutes",
          p95: "15 minutes"
        }
      end

      def calculate_quality_scores
        {
          average_lead_score: current_api_user.leads.where(created_at: @date_range).average(:score)&.round(2),
          high_quality_leads: current_api_user.leads.where(created_at: @date_range).where("score >= ?", 80).count,
          medium_quality_leads: current_api_user.leads.where(created_at: @date_range).where("score >= ? AND score < ?", 50, 80).count,
          low_quality_leads: current_api_user.leads.where(created_at: @date_range).where("score < ?", 50).count
        }
      end

      def calculate_growth_metrics
        # Implementation for growth metrics
        {}
      end

      def fetch_trending_keywords
        # Implementation for trending keywords
        []
      end

      def calculate_conversion_trends
        # Implementation for conversion trends
        {}
      end

      def generate_simple_predictions
        # Simple prediction implementation
        {
          next_week_mentions: "Estimated 150-200",
          next_week_leads: "Estimated 30-45"
        }
      end

      def compile_export_data(data_type)
        case data_type
        when "mentions"
          current_api_user.mentions.where(created_at: @date_range).map { |m| serialize_mention(m) }
        when "leads"
          current_api_user.leads.where(created_at: @date_range).map { |l| serialize_lead(l) }
        when "keywords"
          keywords
        else
          {
            overview: calculate_summary_metrics,
            performance: calculate_performance_metrics,
            funnel: calculate_conversion_funnel
          }
        end
      end

      def generate_csv(data)
        require "csv"
        CSV.generate(headers: true) do |csv|
          if data.is_a?(Array) && data.first.is_a?(Hash)
            csv << data.first.keys
            data.each { |row| csv << row.values }
          elsif data.is_a?(Hash)
            data.each { |key, value| csv << [ key, value.to_json ] }
          end
        end
      end
    end
  end
end
