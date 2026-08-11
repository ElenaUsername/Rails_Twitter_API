require "rails_helper"

RSpec.describe Types::CommentType do
  subject(:comment_type) { described_class }

  it "has the correct graphql name Comment" do
    expect(comment_type.graphql_name).to eq("Comment")
  end

  it "verifies the expected fields exist" do
    expect(comment_type.fields.keys).to contain_exactly(
      "uuid",
      "message",
      "resources"
    )
  end

  it "verifies the comment fields are non-null where expected" do
    expect(comment_type.fields["uuid"].type.non_null?).to be(true)
    expect(comment_type.fields["message"].type.non_null?).to be(true)
    expect(comment_type.fields["resources"].type.non_null?).to be(true)
  end
end
