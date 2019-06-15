# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server do
  it "has SESSION_ID_UNALLOCATED" do
    expect(described_class::SESSION_ID_UNALLOCATED).to eq "UNALLOCATED"
  end

  it "has SESSION_ID_MIN" do
    expect(described_class::SESSION_ID_MIN).to eq 1
  end

  it "has SESSION_ID_MAX" do
    expect(described_class::SESSION_ID_MAX).to eq (2**32 - 1)
  end

  it "has SESSION_ID_MODULO" do
    expect(described_class::SESSION_ID_MODULO).to eq (2**32 - 1)
  end

  describe '#initialize' do
    let(:db){ 'db' }
    let(:datastore){ HrrRbNetconf::Server::Datastore.new db }

    describe "without capability" do
      let(:server){ described_class.new datastore }

      it "doesn't raise error" do
        expect { server }.not_to raise_error
      end

      it "initializes @capabilities" do
        expect(server.instance_variable_get('@capabilities').list_all).to eq HrrRbNetconf::Server::Capabilities.new.list_all
      end

      it "initializes @sessions" do
        expect(server.instance_variable_get('@sessions')).to eq Hash.new
      end
    end

    describe "without capability" do
      let(:features){ [] }
      let(:capabilities){ HrrRbNetconf::Server::Capabilities.new features }
      let(:server){ described_class.new datastore, capabilities: capabilities }

      it "doesn't raise error" do
        expect { server }.not_to raise_error
      end

      it "initializes @capabilities" do
        expect(server.instance_variable_get('@capabilities').list_all).to eq HrrRbNetconf::Server::Capabilities.new.list_all
      end

      it "initializes @sessions" do
        expect(server.instance_variable_get('@sessions')).to eq Hash.new
      end
    end
  end

  describe "#allocate_session_id" do
    let(:db){ 'db' }
    let(:datastore){ HrrRbNetconf::Server::Datastore.new db }
    let(:server){ described_class.new datastore }

    describe "when allocate 3 times" do
      describe "when @sessions is empty" do
        describe "when @last_session_id is initial value" do
          it "allocate 1, 2, and 3" do
            3.times do
              session_id = server.allocate_session_id
              server.instance_variable_get('@sessions')[session_id] = 'dummy'
            end
            expect(server.instance_variable_get('@sessions').keys).to eq [1, 2, 3]
          end
        end

        describe "when @last_session_id is (2**32 - 2)" do
          it "allocate (2**32 - 1), 1, and 2" do
            server.instance_variable_set('@last_session_id', (2**32 - 2))
            3.times do
              session_id = server.allocate_session_id
              server.instance_variable_get('@sessions')[session_id] = 'dummy'
            end
            expect(server.instance_variable_get('@sessions').keys).to eq [(2**32 - 1), 1, 2]
          end
        end
      end

      describe "when @sessions has [1, 3, (2**32 - 2)]" do
        before :example do
          [1, 3, (2**32 - 2)].each{ |session_id|
            server.instance_variable_get('@sessions')[session_id] = 'dummy'
          }
        end

        describe "when @last_session_id is initial value" do
          it "allocate 2, 4, and 5" do
            3.times do
              session_id = server.allocate_session_id
              server.instance_variable_get('@sessions')[session_id] = 'dummy'
            end
            expect(server.instance_variable_get('@sessions').keys).to eq [1, 3, (2**32 - 2), 2, 4, 5]
          end
        end

        describe "when @last_session_id is (2**32 - 2)" do
          it "allocate (2**32 - 1), 2, and 4" do
            server.instance_variable_set('@last_session_id', (2**32 - 2))
            3.times do
              session_id = server.allocate_session_id
              server.instance_variable_get('@sessions')[session_id] = 'dummy'
            end
            expect(server.instance_variable_get('@sessions').keys).to eq [1, 3, (2**32 - 2), (2**32 - 1), 2, 4]
          end
        end
      end
    end
  end

  describe described_class do
    let(:io_class){
      Class.new { |klass|
        attr_reader :local_r, :local_w, :remote_r, :remote_w
        def initialize
          @local_r,  @remote_w = IO.pipe
          @remote_r, @local_w  = IO.pipe
        end
        def close
          @local_r.close rescue nil
          @local_w.close rescue nil
          @remote_r.close rescue nil
          @remote_w.close rescue nil
        end
      }
    }
    let(:io){ io_class.new }
    let(:io2){ io_class.new }

    let(:db){ double("DB") }
    let(:datastore){ HrrRbNetconf::Server::Datastore.new(db) }
    let(:netconf_server){ HrrRbNetconf::Server.new datastore }
    let(:netconf_server_threads){ [] }

    before :example do
    end

    after :example do
      netconf_server_threads.each{ |t| t.exit rescue nil }
      io.close rescue nil
      io2.close rescue nil
    end

    describe "urn:ietf:params:netconf:base:1.0" do
      describe "hello" do
        let(:hello){ <<-'EOB'
          <hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
            <capabilities>
              <capability>urn:ietf:params:netconf:base:1.0</capability>
            </capabilities>
          </hello>
          ]]>]]>
          EOB
        }

        it "exchanges hello and keeps session" do
          netconf_server_threads.push Thread.new {
            netconf_server.start_session([io.local_r, io.local_w])
          }

          io.remote_w.write hello
          local_hello = io.remote_r.readpartial(10240).split("]]>]]>").first
          capability_elems = REXML::Document.new(local_hello).elements['hello/capabilities'].elements.to_a
          expect(capability_elems.any?{|c| c.text == "urn:ietf:params:netconf:base:1.0"}).to be true

          expect(io.local_w.closed?).to be false
          expect(io.local_r.closed?).to be false
        end
      end

      describe "rpc close-session" do
        let(:hello){ <<-'EOB'
          <hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
            <capabilities>
              <capability>urn:ietf:params:netconf:base:1.0</capability>
            </capabilities>
          </hello>
          ]]>]]>
          EOB
        }
        let(:close_session){ <<-'EOB'
          <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="1">
            <close-session />
          </rpc>
          ]]>]]>
          EOB
        }

        it "exchanges hello and closes session" do
          datastore.oper_proc("close-session"){ |db, input_e|
            # do nothing
          }

          netconf_server_threads.push Thread.new {
            netconf_server.start_session([io.local_r, io.local_w])
          }

          io.remote_w.write hello
          local_hello = io.remote_r.readpartial(10240).split("]]>]]>").first

          io.remote_w.write close_session
          rpc_reply_str = io.remote_r.readpartial(10240).split("]]>]]>").first
          rpc_reply_e = REXML::Document.new(rpc_reply_str).root
          expect(rpc_reply_e.attributes["message-id"]).to eq "1"
          expect(rpc_reply_e.elements[1].name).to eq "ok"

          expect(io.local_w.closed?).to be true
          expect(io.local_r.closed?).to be true
        end
      end

      describe "rpc get" do
        describe "when datastore doesn't have block" do
          let(:hello){ <<-'EOB'
            <hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
              <capabilities>
                <capability>urn:ietf:params:netconf:base:1.0</capability>
              </capabilities>
            </hello>
            ]]>]]>
            EOB
          }
          let(:get){ <<-'EOB'
            <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="1">
              <get />
            </rpc>
            ]]>]]>
            EOB
          }
          let(:close_session){ <<-'EOB'
            <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="2">
              <close-session />
            </rpc>
            ]]>]]>
            EOB
          }

          it "returns DB's 'get' output" do
            datastore.oper_proc("get"){ |db, input_e|
              "<root><result /></root>"
            }
            datastore.oper_proc("close-session"){ |db, input_e|
              # do nothing
            }

            netconf_server_threads.push Thread.new {
              netconf_server.start_session([io.local_r, io.local_w])
            }

            io.remote_w.write hello
            local_hello = io.remote_r.readpartial(10240).split("]]>]]>").first

            io.remote_w.write get
            rpc_reply_str = io.remote_r.readpartial(10240).split("]]>]]>").first
            rpc_reply_e = REXML::Document.new(rpc_reply_str).root
            expect(rpc_reply_e.attributes["message-id"]).to eq "1"
            expect(rpc_reply_e.elements[1].name).to eq "root"
            expect(rpc_reply_e.elements[1].elements[1].name).to eq "result"

            io.remote_w.write close_session
            rpc_reply_str = io.remote_r.readpartial(10240).split("]]>]]>").first
            rpc_reply_e = REXML::Document.new(rpc_reply_str).root
            expect(rpc_reply_e.attributes["message-id"]).to eq "2"
            expect(rpc_reply_e.elements[1].name).to eq "ok"

            expect(io.local_w.closed?).to be true
            expect(io.local_r.closed?).to be true
          end
        end

        describe "when datastore has block" do
          let(:db_session){ double("DB session") }
          let(:datastore){
            HrrRbNetconf::Server::Datastore.new(db){ |db, session, oper_handler|
              begin
                oper_handler.start db_session, "dummy arg"
              ensure
                db_session.close rescue nil
              end
            }
          }

          let(:hello){ <<-'EOB'
            <hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
              <capabilities>
                <capability>urn:ietf:params:netconf:base:1.0</capability>
              </capabilities>
            </hello>
            ]]>]]>
            EOB
          }
          let(:get){ <<-'EOB'
            <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="1">
              <get />
            </rpc>
            ]]>]]>
            EOB
          }
          let(:close_session){ <<-'EOB'
            <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="2">
              <close-session />
            </rpc>
            ]]>]]>
            EOB
          }

          it "returns DB's 'get' output" do
            datastore.oper_proc("get"){ |db_session, dummy_arg, input_e|
              db_session.called
              "<root><result>#{dummy_arg}</result></root>"
            }
            datastore.oper_proc("close-session"){ |db_session, dummy_arg, input_e|
              db_session.close
            }

            netconf_server_threads.push Thread.new {
              netconf_server.start_session([io.local_r, io.local_w])
            }

            expect(db_session).to receive(:called).with(no_args).once
            expect(db_session).to receive(:close).with(no_args).twice

            io.remote_w.write hello
            local_hello = io.remote_r.readpartial(10240).split("]]>]]>").first

            io.remote_w.write get
            rpc_reply_str = io.remote_r.readpartial(10240).split("]]>]]>").first
            rpc_reply_e = REXML::Document.new(rpc_reply_str).root
            expect(rpc_reply_e.attributes["message-id"]).to eq "1"
            expect(rpc_reply_e.elements[1].name).to eq "root"
            expect(rpc_reply_e.elements[1].elements[1].name).to eq "result"
            expect(rpc_reply_e.elements[1].elements[1].text).to eq "dummy arg"

            io.remote_w.write close_session
            rpc_reply_str = io.remote_r.readpartial(10240).split("]]>]]>").first
            rpc_reply_e = REXML::Document.new(rpc_reply_str).root
            expect(rpc_reply_e.attributes["message-id"]).to eq "2"
            expect(rpc_reply_e.elements[1].name).to eq "ok"

            expect(io.local_w.closed?).to be true
            expect(io.local_r.closed?).to be true
          end
        end
      end
    end
  end
end
