module Mutations
  class TweetCreate < BaseMutation
    argument :content, String, required: true

    field :tweet, Types::TweetType, null: false

    def resolve(content:)
      tweet = Tweet.create!(content: content)
      { tweet: tweet }
    end
  end
end
