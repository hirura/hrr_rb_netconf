# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Errors do
  it "includes Enumerable" do
    expect( described_class.include? Enumerable ).to be true
  end

  let(:types){ ['transport', 'rpc', 'protocol', 'application'] }
  let(:severities){ ['error'] }
  let(:infos){ [] }
  let(:tag1){ 'error1' }
  let(:type1){ 'transport' }
  let(:severity2){ 'error' }
  let(:tag2){ 'error2' }
  let(:type2){ 'rpc' }
  let(:severity1){ 'error' }
  let(:error1){
    klass = Class.new(HrrRbNetconf::Server::Error){ include HrrRbNetconf::Server::Error::RpcErrorable }
    klass.const_set :TAG,      tag1
    klass.const_set :TYPE,     types
    klass.const_set :SEVERITY, severities
    klass.const_set :INFO,     infos
    klass.new(type1, severity1)
  }
  let(:error2){
    klass = Class.new(HrrRbNetconf::Server::Error){ include HrrRbNetconf::Server::Error::RpcErrorable }
    klass.const_set :TAG,      tag2
    klass.const_set :TYPE,     types
    klass.const_set :SEVERITY, severities
    klass.const_set :INFO,     infos
    klass.new(type2, severity2)
  }

  describe "#initialize" do
    describe "with one arg that is a kind of Error" do
      let(:arg1){ error1 }
      let(:errors){ described_class.new arg1 }

      it "doesn't raise error" do
        expect{ errors }.not_to raise_error
      end
    end

    describe "with multiple args that is a kind of Error" do
      let(:arg1){ error1 }
      let(:arg2){ error2 }
      let(:errors){ described_class.new arg1, arg2 }

      it "doesn't raise error" do
        expect{ errors }.not_to raise_error
      end
    end

    describe "with one arg that is an instance of Array with a element that is a kind of Error" do
      let(:arg1){ [error1] }
      let(:errors){ described_class.new arg1 }

      it "doesn't raise error" do
        expect{ errors }.not_to raise_error
      end
    end

    describe "with one arg that is an instance of Array with elements that is a kind of Error" do
      let(:arg1){ [error1, error2] }
      let(:errors){ described_class.new arg1 }

      it "doesn't raise error" do
        expect{ errors }.not_to raise_error
      end
    end

    describe "with args that contain arg that is not a kind of Error" do
      let(:arg1){ error1 }
      let(:arg2){ 'invalid' }
      let(:errors){ described_class.new arg1, arg2 }

      it "raises error" do
        expect{ errors }.to raise_error ArgumentError
      end
    end

    describe "with one arg that is an instance of Array with a element that is not a kind of Error" do
      let(:arg1){ [error1, 'invalid'] }
      let(:errors){ described_class.new arg1 }

      it "raises error" do
        expect{ errors }.to raise_error ArgumentError
      end
    end
  end

  describe "#each" do
    describe "with no block" do
      let(:arg1){ error1 }
      let(:arg2){ error2 }
      let(:errors){ described_class.new arg1, arg2 }

      it "returns Enumerator" do
        expect(errors.each.kind_of? Enumerator).to be true
        expect(errors.each.to_a).to eq [arg1, arg2]
      end
    end

    describe "with block" do
      let(:arg1){ error1 }
      let(:arg2){ error2 }
      let(:errors){ described_class.new arg1, arg2 }

      it "iterates each arg" do
        ary = []
        errors.each{ |e| ary.push e }
        expect(ary).to eq [arg1, arg2]
      end
    end
  end

  describe "#to_a by Enumerable" do
    let(:arg1){ error1 }
    let(:arg2){ error2 }
    let(:errors){ described_class.new arg1, arg2 }

    it "returns an array of args" do
      expect(errors.to_a).to eq [arg1, arg2]
    end
  end
end
