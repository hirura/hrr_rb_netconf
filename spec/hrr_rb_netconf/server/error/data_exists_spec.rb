# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Error::DataExists do
  let(:tag){ 'data-exists' }
  let(:type){ ['application'] }
  let(:severity){ ['error'] }
  let(:info){ [] }

  it "can be looked up in HrrRbNetconf::Server::Error dictionary" do
    expect( HrrRbNetconf::Server::Error[tag] ).to eq described_class
  end

  it "is registered in HrrRbNetconf::Server::Error.list" do
    expect( HrrRbNetconf::Server::Error.list ).to include tag
  end

  it "includes HrrRbNetconf::Server::Error::RpcErrorable" do
    expect( described_class.include? HrrRbNetconf::Server::Error::RpcErrorable ).to be true
  end

  it "has correct TYPE" do
    expect( described_class::TYPE ).to eq type
  end

  it "has correct SEVERITY" do
    expect( described_class::SEVERITY ).to eq severity
  end

  it "has correct INFO" do
    expect( described_class::INFO ).to eq info
  end
end
