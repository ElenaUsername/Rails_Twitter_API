require "rails_helper"

RSpec.describe Types::TweetType do
  subject(:tweet_type) { described_class }

  it "has the correct graphql name Tweet" do
    expect(tweet_type.graphql_name).to eq("Tweet")
  end

  it "verify the expected fields existance uuid" do
    expect(tweet_type.fields.keys).to contain_exactly(
      "uuid",
    )
  end

  it "verify the uuid is not null" do
    expect(tweet_type.fields["uuid"].type.non_null?).to be(true)
  end
end
