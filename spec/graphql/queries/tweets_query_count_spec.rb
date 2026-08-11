require 'rails_helper'

RSpec.describe 'tweets query database load', type: :request do
  let(:query) do
    <<~GRAPHQL
      query {
        tweets {
          uuid
          message
          resources {
            title
            description
            url
            image {
              url
              byteSize
            }
          }
          comments {
            uuid
            message
            resources {
              title
              description
              url
              image {
                url
                byteSize
              }
            }
          }
        }
      }
    GRAPHQL
  end

  # Cached queries keep their real name in Rails 8.1 and are only identifiable
  # through payload[:cached]; SCHEMA and TRANSACTION are real names to skip.
  def collect_queries
    queries = []

    callback = lambda do |*, payload|
      next if payload[:cached]
      next if %w[SCHEMA TRANSACTION].include?(payload[:name])

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }

    queries
  end

  before do
    3.times do |i|
      tweet = Tweet.create!(content: "tweet #{i} https://example.com/t#{i}")
      tweet.resource_descriptions.create!(
        title: "Tweet resource #{i}",
        description: 'A description',
        url: "https://example.com/t#{i}",
        image: Image.create!(url: "https://example.com/t#{i}.png", byte_size: 100 + i)
      )

      2.times do |j|
        comment = tweet.comments.create!(content: "comment #{i}#{j} https://example.com/c#{i}#{j}")
        comment.resource_descriptions.create!(
          title: "Comment resource #{i}#{j}",
          description: 'A description',
          url: "https://example.com/c#{i}#{j}",
          image: Image.create!(url: "https://example.com/c#{i}#{j}.png", byte_size: 200 + j)
        )
      end
    end
  end

  it 'loads three tweets, their comments and every resource in a fixed number of queries' do
    queries = collect_queries do
      post '/graphql', params: { query: query }, as: :json
    end

    json = JSON.parse(response.body)
    expect(json['errors']).to be_nil
    expect(json['data']['tweets'].length).to eq(3)
    expect(json['data']['tweets'].first['comments'].length).to eq(2)
    expect(json['data']['tweets'].first['comments'].first['resources'].length).to eq(1)

    # Six: tweets, their resource_descriptions, those images, comments, their
    # resource_descriptions, those images. Constant in the number of tweets and
    # comments -- without eager loading this same query fires 22.
    expect(queries.length).to eq(6), <<~MESSAGE
      Expected 6 queries, got #{queries.length}:
      #{queries.map.with_index(1) { |sql, i| "  #{i}. #{sql}" }.join("\n")}
    MESSAGE
  end

  it 'preloads nothing for a query that selects no associations' do
    queries = collect_queries do
      post '/graphql', params: { query: 'query { tweets { uuid message } }' }, as: :json
    end

    json = JSON.parse(response.body)
    expect(json['errors']).to be_nil
    expect(json['data']['tweets'].length).to eq(3)

    # Only the tweets themselves. Eager loading unconditionally would preload
    # comments, resources and images the client never asked for.
    expect(queries.length).to eq(1), <<~MESSAGE
      Expected 1 query, got #{queries.length}:
      #{queries.map.with_index(1) { |sql, i| "  #{i}. #{sql}" }.join("\n")}
    MESSAGE
  end

  it 'preloads resources but not comments when only resources are selected' do
    shallow = 'query { tweets { uuid resources { title image { url } } } }'

    queries = collect_queries do
      post '/graphql', params: { query: shallow }, as: :json
    end

    expect(JSON.parse(response.body)['errors']).to be_nil

    # Tweets, their resource_descriptions, those images. No comments query.
    expect(queries.length).to eq(3), <<~MESSAGE
      Expected 3 queries, got #{queries.length}:
      #{queries.map.with_index(1) { |sql, i| "  #{i}. #{sql}" }.join("\n")}
    MESSAGE
  end
end
