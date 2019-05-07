# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Error do
  describe '[key]' do
    it "returns nil for dummy key" do
      expect( described_class['dummy key'] ).to be nil
    end
  end

  describe '.list' do
    it "returns an instance of Array" do
      expect( described_class.list ).to be_an_instance_of Array
    end
  end
end
