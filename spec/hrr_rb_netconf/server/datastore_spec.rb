# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Datastore do
  let(:db){ 'db' }
  let(:datastore){ described_class.new db }

  describe "#operation_proc" do
    it "saves operation with specified operation name" do
      datastore.operation_proc('operation'){ db }
      expect(datastore.operation_proc('operation').call).to eq db
    end
  end
end
