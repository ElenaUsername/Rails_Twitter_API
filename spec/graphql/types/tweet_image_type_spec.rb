require "rails_helper"

RSpec.describe Types::TweetImageType do
  subject(:image_type) { described_class }

  it "has the correct graphql name Image" do
    expect(image_type.graphql_name).to eq("Image")
  end

  it "verify the expected fields existance url and byteSize" do
    expect(image_type.fields.keys).to contain_exactly(
      "url",
      "byteSize"
    )
  end

  it "verify the fiels url and byte_size is not null" do
    expect(image_type.fields["url"].type.non_null?).to be(true)
    expect(image_type.fields["byteSize"].type.non_null?).to be(true)
  end
end
