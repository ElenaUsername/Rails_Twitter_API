require 'rails_helper'

RSpec.describe 'TweetCreate mutation', type: :request do
  let(:query) do
    <<~GRAPHQL
      mutation($input: TweetCreateInput!) {
        tweetCreate(input: $input) {
          tweet {
            uuid
          }
        }
      }
    GRAPHQL
  end

  let(:variables) do
    {
      input: {
        content: tweet_content
      }
    }
  end

  let(:tweet_content) { 'How to sleep 10 hours in 1 hour' }

  it 'creates a tweet and returns the tweet payload' do
    expect do
      post '/graphql', params: { query: query, variables: variables }, as: :json
    end.to change(Tweet, :count).by(1)

    expect(response).to have_http_status(200)

    json = JSON.parse(response.body)
    expect(json['errors']).to be_nil
    expect(json['data']['tweetCreate']).to be_present
    expect(json['data']['tweetCreate']['tweet']['uuid']).to be_present
  end
end
