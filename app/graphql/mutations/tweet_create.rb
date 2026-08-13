module Mutations
  class TweetCreate < BaseMutation
    argument :content, String, required: true

    field :tweet, Types::TweetType, null: false

    def resolve(content:)
      tweet = Tweet.create!(content: content)
      OpenGraphExtractionJob.perform_later(tweet)
      { tweet: tweet }
    rescue ActiveRecord::RecordInvalid => e
      raise GraphQL::ExecutionError, e.record.errors.full_messages.to_sentence
    end
  end
end
