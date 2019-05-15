# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Filter do
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

  describe '.filter' do
    let(:filter){
      klass = Class.new(HrrRbNetconf::Server::Filter){
        def self.filter raw_output_e, input_e
          raw_output_e
        end
      }
      klass.const_set :TYPE, 'valid'
      klass
    }

    before :example do
      filter
    end

    after :example do
      described_class.instance_variable_get('@subclass_list').delete filter
    end

    describe "with filter element" do
      describe "when filter is valid" do
        let(:raw_output_e){ '<a xmlns="ab"><b/></a>' }
        let(:input_e){ REXML::Document.new('<get><filter type="valid" /></get>').root }
        it "returns output filtered" do
          expect( described_class['valid'] ).to eq filter
          expect( described_class.filter raw_output_e, input_e ).to eq raw_output_e
        end
      end

      describe "when filter is invalid" do
        let(:raw_output_e){ '<a xmlns="ab"><b/></a>' }
        let(:input_e){ REXML::Document.new('<get><filter type="invalid" /></get>').root }
        it "returns output filtered" do
          expect{ described_class.filter raw_output_e, input_e }.to raise_error HrrRbNetconf::Server::Error['bad-attribute']
        end
      end
    end

    describe "without filter element" do
      let(:raw_output_e){ '<a xmlns="ab"><b/></a>' }
      let(:input_e){ REXML::Document.new('<get />').root }
      it "returns output filtered" do
        expect( described_class.filter raw_output_e, input_e ).to eq raw_output_e
      end
    end
  end
end
