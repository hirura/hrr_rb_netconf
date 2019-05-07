# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server do
  describe '.new' do
    it "doesn't raise error" do
      expect { described_class.new }.not_to raise_error
    end
  end
end
