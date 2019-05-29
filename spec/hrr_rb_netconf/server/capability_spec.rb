# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Capability do
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

  describe '.oper_procs' do
    it "returns an instance of Hash" do
      expect( described_class.oper_procs ).to be_an_instance_of Hash
    end
  end

  describe '.oper_proc' do
    after :example do
      described_class.instance_variable_get('@oper_procs').clear
    end

    it "registeres operation proc" do
      described_class.send(:oper_proc, 'oper1', &Proc.new{ |dummy| })
      expect( described_class.instance_variable_get('@oper_procs').has_key?('oper1') ).to be true
    end
  end

  describe "#initialize" do
    describe "with id" do
      let(:capability){ described_class.new id }
      let(:id){ 'cap1' }

      it "initialize id, if_features, dependencies, and oper_procs" do
        expect( capability.id ).to eq id
        expect( capability.if_features ).to eq Array.new
        expect( capability.dependencies ).to eq Array.new
        expect( capability.oper_procs ).to eq Hash.new
      end
    end
  end
end
