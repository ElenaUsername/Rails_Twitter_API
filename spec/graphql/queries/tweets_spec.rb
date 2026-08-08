require 'rails_helper'

RSpec.describe 'tweets query', type: :request do
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
        }
      }
    GRAPHQL
  end

  context 'when there are no tweets' do
    it 'returns an empty list' do
      post '/graphql', params: { query: query }, as: :json

      expect(response).to have_http_status(200)

      json = JSON.parse(response.body)
      expect(json['errors']).to be_nil
      expect(json['data']['tweets']).to eq([])
    end
  end

  context 'when a tweet has resources' do
    let(:tweet) { Tweet.create!(content: 'check this out https://example.com/article') }
    let(:image) { Image.create!(url: 'https://example.com/image.png', byte_size: 12_345) }

    before do
      tweet.resource_descriptions.create!(
        title: 'Cool Article',
        description: 'A description',
        url: 'https://example.com/article',
        image: image
      )
    end

    it 'returns the tweet with its resources' do
      post '/graphql', params: { query: query }, as: :json

      expect(response).to have_http_status(200)

      json = JSON.parse(response.body)
      expect(json['errors']).to be_nil

      returned_tweet = json['data']['tweets'].first
      expect(returned_tweet['uuid']).to eq(tweet.uuid)
      expect(returned_tweet['message']).to eq(tweet.content)

      resource = returned_tweet['resources'].first
      expect(resource['title']).to eq('Cool Article')
      expect(resource['description']).to eq('A description')
      expect(resource['url']).to eq('https://example.com/article')
      expect(resource['image']).to eq('url' => 'https://example.com/image.png', 'byteSize' => 12_345)
    end
  end
end
