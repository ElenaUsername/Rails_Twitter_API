require "rails_helper"

RSpec.describe Types::TweetCreateInputType do
  subject(:tweet_create) { described_class }

  it "has the correct graphql name TweetCreateInput" do
    expect(tweet_create.graphql_name).to eq("TweetCreateInput")
  end

  it "verify the fiels content is not null" do
    expect(tweet_create.arguments["content"].type.non_null?).to be(true)
  end
end
