# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Capability::Candidate_1_0 do
  let(:id){ 'urn:ietf:params:netconf:capability:candidate:1.0' }

  it "can be looked up in HrrRbNetconf::Server::Capability dictionary" do
    expect( HrrRbNetconf::Server::Capability[id] ).to eq described_class
  end       

  it "is registered in HrrRbNetconf::Server::Capability.list" do
    expect( HrrRbNetconf::Server::Capability.list ).to include id
  end         
end
