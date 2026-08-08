require "rails_helper"

RSpec.describe Types::ResourceDescriptionType do
  subject(:resource_description) { described_class }

  it "has the correct graphql name ResourceDescription" do
    expect(resource_description.graphql_name).to eq("ResourceDescription")
  end

  it "verify the expected fields existance url and byteSize" do
    expect(resource_description.fields.keys).to contain_exactly(
      "title",
      "description",
      "url",
      "image"
    )
  end

  it "verify the fiels url and byte_size is not null" do
    expect(resource_description.fields["title"].type.non_null?).to be(true)
    expect(resource_description.fields["description"].type.non_null?).to be(true)
    expect(resource_description.fields["url"].type.non_null?).to be(true)
    expect(resource_description.fields["image"].type.non_null?).to be(true)
  end
end
