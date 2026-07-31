module Types
  class TweetCreateInputType < Types::BaseInputObject
    graphql_name "TweetCreateInput"

    argument :content, String, required: true
  end
end
