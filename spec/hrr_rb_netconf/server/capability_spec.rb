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

  describe '#oper_procs' do
    let(:capability){ described_class.new id }
    let(:id){ 'cap1' }

    it "returns an instance of Hash" do
      expect( capability.oper_procs ).to be_an_instance_of Hash
    end
  end

  describe '#oper_proc' do
    let(:capability){ described_class.new id }
    let(:id){ 'cap1' }

    it "registeres operation proc" do
      capability.send(:oper_proc, 'oper1', &Proc.new{ |dummy| })
      expect( capability.instance_variable_get('@oper_procs').has_key?('oper1') ).to be true
    end
  end

  describe "#negotiate" do
    let(:capability){ described_class.new id }

    describe "with same capability" do
      let(:id){ 'urn:cap1:1.0' }
      let(:other_id){ 'urn:cap1:1.0' }

      it "returns original capability" do
        expect(capability.negotiate other_id).to eq capability
      end
    end

    describe "with different version capability" do
      let(:id){ 'urn:cap1:1.0' }
      let(:other_id){ 'urn:cap1:1.1' }

      it "returns nil" do
        expect(capability.negotiate other_id).to be nil
      end
    end

    describe "with different version capability but version_proc always returns same value" do
      let(:id){ 'urn:cap1:1.0' }
      let(:other_id){ 'urn:cap1:1.1' }

      it "returns nil" do
        capability.version_proc { '1.0' }
        expect(capability.negotiate other_id).to eq capability
      end
    end

    describe "with same version capability but partial match query values" do
      let(:id){ 'urn:cap1:1.0' }
      let(:other_id){ 'urn:cap1:1.0?scheme=bar,baz' }

      it "returns same capability with common queries" do
        capability.queries = {'scheme' => ['foo', 'bar']}
        expect(capability.negotiate(other_id).id).to eq 'urn:cap1:1.0?scheme=bar'
      end
    end

    describe "with same version capability but non match query values" do
      let(:id){ 'urn:cap1:1.0' }
      let(:other_id){ 'urn:cap1:1.0?scheme=baz' }

      it "returns same capability with common queries" do
        capability.queries = {'scheme' => ['foo', 'bar']}
        expect(capability.negotiate(other_id).id).to eq 'urn:cap1:1.0'
      end
    end

    describe "with same version capability that version is set as query" do
      let(:id){ 'urn:cap1' }
      let(:other_id){ 'urn:cap1?version=1.0' }

      it "returns same capability with common queries" do
        capability.queries = {'version' => ['1.0']}
        capability.keyword_proc { |id| id.split('?').first }
        capability.version_proc { |id| URI.decode_www_form((id.split('?') + [''])[1]).inject({}){|a,(k,v)| a.merge({k => v})}['version'][0] }
        expect(capability.negotiate other_id).to eq capability
      end
    end
  end
end
