require 'rails_helper'

RSpec.describe 'CommentCreate mutation', type: :request do
  let(:query) do
    <<~GRAPHQL
      mutation($input: CommentCreateInput!) {
        commentCreate(input: $input) {
          comment {
            uuid
          }
        }
      }
    GRAPHQL
  end

  let(:variables) do
    {
      input: {
        tweetUuid: tweet_uuid,
        content: comment_content
      }
    }
  end

  let(:comment_content) { 'This is exactly the ladder I needed: https://12ft.io/' }

  context 'when the tweetUuid exists' do
    let(:tweet) { Tweet.create!(content: 'Best thing I found in a while: https://12ft.io/') }
    let(:tweet_uuid) { tweet.uuid }

    it 'creates a comment on that tweet and returns the comment payload' do
      expect do
        post '/graphql', params: { query: query, variables: variables }, as: :json
      end.to change(Comment, :count).by(1)

      expect(response).to have_http_status(200)

      json = JSON.parse(response.body)
      expect(json['errors']).to be_nil
      expect(json['data']['commentCreate']['comment']['uuid']).to be_present

      comment = Comment.last
      expect(comment.uuid).to eq(json['data']['commentCreate']['comment']['uuid'])
      expect(comment.tweet).to eq(tweet)
      expect(comment.content).to eq(comment_content)
    end

    it 'enqueues the Open Graph extraction for the comment' do
      # The block form is evaluated when the matcher runs, not when it is built.
      # Passing Comment.last directly would pass nil, which rspec-rails treats
      # as "no argument expectation" and skips.
      expect do
        post '/graphql', params: { query: query, variables: variables }, as: :json
      end.to have_enqueued_job(OpenGraphExtractionJob)
        .with { |record| expect(record).to eq(Comment.last) }
    end
  end

  context 'when the tweetUuid does not exist' do
    let(:tweet_uuid) { '1231-1231-1231-1231' }

    it 'returns a GraphQL error rather than a comment with a null field' do
      expect do
        post '/graphql', params: { query: query, variables: variables }, as: :json
      end.not_to change(Comment, :count)

      expect(response).to have_http_status(200)

      json = JSON.parse(response.body)
      expect(json['errors'].length).to eq(1)
      expect(json['errors'].first['message']).to eq('Tweet not found: 1231-1231-1231-1231')
      expect(json['errors'].first['path']).to eq([ 'commentCreate' ])
      expect(json['data']).to eq('commentCreate' => nil)

      # Returning { comment: nil } instead of raising would also satisfy the
      # assertions above, but would surface as a non-nullable field violation.
      expect(json['errors'].map { |error| error['message'] })
        .not_to include(a_string_matching(/Cannot return null for non-nullable field/))
    end

    it 'does not enqueue an Open Graph extraction' do
      expect do
        post '/graphql', params: { query: query, variables: variables }, as: :json
      end.not_to have_enqueued_job(OpenGraphExtractionJob)
    end
  end
end
