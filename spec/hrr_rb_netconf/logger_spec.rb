# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Logger do
  let(:name){ 'spec' }
  let(:internal_logger){
    Class.new{
      def fatal; yield; end
      def error; yield; end
      def warn;  yield; end
      def info;  yield; end
      def debug; yield; end
    }.new
  }
  let(:logger){ described_class.new name }

  describe '.initialize' do
    it "takes one argument" do
      expect { HrrRbNetconf::Logger.initialize internal_logger }.not_to raise_error
    end

    it "initialize HrrRbNetconf::Logger" do
      HrrRbNetconf::Logger.initialize internal_logger
      expect(HrrRbNetconf::Logger.initialized?).to be true
    end
  end

  describe '.uninitialize' do
    it "takes no arguments" do
      expect { HrrRbNetconf::Logger.uninitialize }.not_to raise_error
    end

    it "uninitialize HrrRbNetconf::Logger" do
      HrrRbNetconf::Logger.initialize internal_logger
      HrrRbNetconf::Logger.uninitialize
      expect(HrrRbNetconf::Logger.initialized?).to be false
    end
  end

  describe '.initialized?' do
    it "is false when uninitialized" do
      HrrRbNetconf::Logger.initialize internal_logger
      HrrRbNetconf::Logger.uninitialize
      expect(HrrRbNetconf::Logger.initialized?).to be false
    end

    it "is true when initialized" do
      HrrRbNetconf::Logger.initialize internal_logger
      expect(HrrRbNetconf::Logger.initialized?).to be true
    end
  end

  describe '#new' do
    it "takes one argument" do
      expect { HrrRbNetconf::Logger.new name }.not_to raise_error
    end
  end

  describe '#fatal' do
    let(:method){ :fatal }

    context 'HrrRbNetconf::Logger is not initialized' do
      before :example do
        HrrRbNetconf::Logger.uninitialize
      end
      it "does not call #fatal method of @@logger" do
        expect { logger.send(method){ method } }.not_to raise_error
      end
    end

    context 'HrrRbNetconf::Logger is initialized' do
      before :example do
        HrrRbNetconf::Logger.initialize internal_logger
      end
      it "calls #fatal method of @@logger with 'p#\{Process.pid\}.t#\{Thread.current.object_id\}: #\{name\}: ' prefix" do
        expect(logger.send(method){ method }).to eq "p#{Process.pid}.t#{Thread.current.object_id}: #{name}: #{method}"
      end
    end
  end

  describe '#error' do
    let(:method){ :error }

    context 'HrrRbNetconf::Logger is not initialized' do
      before :example do
        HrrRbNetconf::Logger.uninitialize
      end
      it "does not call #error method of @@logger" do
        expect { logger.send(method){ method } }.not_to raise_error
      end
    end

    context 'HrrRbNetconf::Logger is initialized' do
      before :example do
        HrrRbNetconf::Logger.initialize internal_logger
      end
      it "calls #error method of @@logger with 'p#\{Process.pid\}.t#\{Thread.current.object_id\}: #\{name\}: ' prefix" do
        expect(logger.send(method){ method }).to eq "p#{Process.pid}.t#{Thread.current.object_id}: #{name}: #{method}"
      end
    end
  end

  describe '#warn' do
    let(:method){ :warn }

    context 'HrrRbNetconf::Logger is not initialized' do
      before :example do
        HrrRbNetconf::Logger.uninitialize
      end
      it "does not call #warn method of @@logger" do
        expect { logger.send(method){ method } }.not_to raise_error
      end
    end

    context 'HrrRbNetconf::Logger is initialized' do
      before :example do
        HrrRbNetconf::Logger.initialize internal_logger
      end
      it "calls #warn method of @@logger with 'p#\{Process.pid\}.t#\{Thread.current.object_id\}: #\{name\}: ' prefix" do
        expect(logger.send(method){ method }).to eq "p#{Process.pid}.t#{Thread.current.object_id}: #{name}: #{method}"
      end
    end
  end

  describe '#info' do
    let(:method){ :info }

    context 'HrrRbNetconf::Logger is not initialized' do
      before :example do
        HrrRbNetconf::Logger.uninitialize
      end
      it "does not call #info method of @@logger" do
        expect { logger.send(method){ method } }.not_to raise_error
      end
    end

    context 'HrrRbNetconf::Logger is initialized' do
      before :example do
        HrrRbNetconf::Logger.initialize internal_logger
      end
      it "calls #info method of @@logger with 'p#\{Process.pid\}.t#\{Thread.current.object_id\}: #\{name\}: ' prefix" do
        expect(logger.send(method){ method }).to eq "p#{Process.pid}.t#{Thread.current.object_id}: #{name}: #{method}"
      end
    end
  end

  describe '#debug' do
    let(:method){ :debug }

    context 'HrrRbNetconf::Logger is not initialized' do
      before :example do
        HrrRbNetconf::Logger.uninitialize
      end
      it "does not call #debug method of @@logger" do
        expect { logger.send(method){ method } }.not_to raise_error
      end
    end

    context 'HrrRbNetconf::Logger is initialized' do
      before :example do
        HrrRbNetconf::Logger.initialize internal_logger
      end
      it "calls #debug method of @@logger with 'p#\{Process.pid\}.t#\{Thread.current.object_id\}: #\{name\}: ' prefix" do
        expect(logger.send(method){ method }).to eq "p#{Process.pid}.t#{Thread.current.object_id}: #{name}: #{method}"
      end
    end
  end
end
