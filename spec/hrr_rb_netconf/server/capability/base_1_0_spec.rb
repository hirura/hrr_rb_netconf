# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Capability::Base_1_0 do
  let(:id){ 'urn:ietf:params:netconf:base:1.0' }
  let(:capability){ described_class.new }

  it "can be looked up in HrrRbNetconf::Server::Capability dictionary" do
    expect( HrrRbNetconf::Server::Capability[id] ).to eq described_class
  end       

  it "is registered in HrrRbNetconf::Server::Capability.list" do
    expect( HrrRbNetconf::Server::Capability.list ).to include id
  end         

  describe '::Sender' do
    let(:io_w){ StringIO.new }
    let(:sender){ described_class::Sender.new io_w }

    describe "when message is a kind of String" do
      describe "when message is well-formed" do
        it "sends message with ']]>]]>' suffix" do
          sender.send_message "<a><b /></a>"
          expect(io_w.string).to eq "<a>\n  <b/>\n</a>\n]]>]]>\n"
        end
      end

      describe "when message is not well-formed" do
        it "raises error" do
          expect { sender.send_message "invalid" }.to raise_error
        end
      end
    end

    describe "when message is a kind of REXML::Document" do
      it "sends message with ']]>]]>' suffix" do
        sender.send_message REXML::Document.new("<a><b /></a>", {:ignore_whitespace_nodes => :all})
        expect(io_w.string).to eq "<a>\n  <b/>\n</a>\n]]>]]>\n"
      end
    end

    describe "when message is a kind of REXML::Element" do
      it "sends message with ']]>]]>' suffix" do
        sender.send_message REXML::Document.new("<a><b /></a>", {:ignore_whitespace_nodes => :all}).root
        expect(io_w.string).to eq "<a>\n  <b/>\n</a>\n]]>]]>\n"
      end
    end

    describe "when message is neither a kind of String, REXML::Document, nor REXML::Element" do
      it "raises error" do
        expect { sender.send_message 0 }.to raise_error
      end
    end
  end

  describe '::Receiver' do
    let(:io_r){ StringIO.new }
    let(:receiver){ described_class::Receiver.new io_r }
    let(:formatter){ f = REXML::Formatters::Pretty.new(2); f.compact = true; f }
    let(:received_message){ buf = String.new; formatter.write(receiver.receive_message, buf); buf }

    describe "when receives valid message" do
      it "returns XML element" do
        io_r.reopen '<a><b /></a>]]>]]>'
        expect(received_message).to eq "<a>\n  <b/>\n</a>"
      end
    end

    describe "when receives invalid message" do
      it "raises error" do
        io_r.reopen 'invalid]]>]]>'
        expect { received_message }.to raise_error
      end
    end
  end
end
