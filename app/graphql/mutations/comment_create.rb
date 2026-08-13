module Mutations
  class CommentCreate < BaseMutation
    argument :tweet_uuid, ID, required: true
    argument :content, String, required: true

    field :comment, Types::CommentType, null: false

    def resolve(tweet_uuid:, content:)
      tweet = Tweet.find_by(uuid: tweet_uuid)
      raise GraphQL::ExecutionError, "Tweet not found: #{tweet_uuid}" if tweet.nil?

      comment = tweet.comments.create!(content: content)
      OpenGraphExtractionJob.perform_later(comment)
      { comment: comment }
    rescue ActiveRecord::RecordInvalid => e
      raise GraphQL::ExecutionError, e.record.errors.full_messages.to_sentence
    end
  end
end
