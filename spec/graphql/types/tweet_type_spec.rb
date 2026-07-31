require "rails_helper"

RSpec.describe Types::TweetType do
  subject(:tweet_type) { described_class }

  it "has the correct graphql name Tweet" do
    expect(tweet_type.graphql_name).to eq("Tweet")
  end

  it "verifies the expected fields exist" do
    expect(tweet_type.fields.keys).to contain_exactly(
      "uuid",
      "message",
      "resources"
    )
  end

  it "verifies the tweet fields are non-null where expected" do
    expect(tweet_type.fields["uuid"].type.non_null?).to be(true)
    expect(tweet_type.fields["message"].type.non_null?).to be(true)
    expect(tweet_type.fields["resources"].type.non_null?).to be(true)
  end
end
