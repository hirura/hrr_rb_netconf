# coding: utf-8
# vim: et ts=2 sw=2

require 'timeout'

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

  describe "Capability based specs" do
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

    after :example do
      io.close rescue nil
      io2.close rescue nil
      netconf_server_threads.each{ |t| t.exit rescue nil }
      netconf_server_threads.each{ |t| t.join rescue nil }
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
            begin
              netconf_server.start_session([io.local_r, io.local_w])
            rescue IOError
            end
          }

          io.remote_w.write hello
          msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
          capability_elems = REXML::Document.new(msg).elements['hello/capabilities'].elements.to_a
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
            begin
              netconf_server.start_session([io.local_r, io.local_w])
            rescue IOError
            end
          }

          io.remote_w.write hello
          msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

          io.remote_w.write close_session
          msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
          msg_e = REXML::Document.new(msg).root
          expect(msg_e.attributes["message-id"]).to eq "1"
          expect(msg_e.elements[1].name).to eq "ok"

          io.remote_w.close_write rescue nil
          io.remote_r.close_read  rescue nil

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

          it "replies DB's 'get' output" do
            datastore.oper_proc("get"){ |db, input_e|
              "<root><result /></root>"
            }
            datastore.oper_proc("close-session"){ |db, input_e|
              # do nothing
            }

            netconf_server_threads.push Thread.new {
              begin
                netconf_server.start_session([io.local_r, io.local_w])
              rescue IOError
              end
            }

            io.remote_w.write hello
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

            io.remote_w.write get
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
            msg_e = REXML::Document.new(msg).root
            expect(msg_e.attributes["message-id"]).to eq "1"
            expect(msg_e.elements[1].name).to eq "root"
            expect(msg_e.elements[1].elements[1].name).to eq "result"

            io.remote_w.write close_session
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
            msg_e = REXML::Document.new(msg).root
            expect(msg_e.attributes["message-id"]).to eq "2"
            expect(msg_e.elements[1].name).to eq "ok"

            io.remote_w.close_write rescue nil
            io.remote_r.close_read  rescue nil

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

          it "replies DB's 'get' output" do
            datastore.oper_proc("get"){ |db_session, dummy_arg, input_e|
              db_session.called
              "<root><result>#{dummy_arg}</result></root>"
            }
            datastore.oper_proc("close-session"){ |db_session, dummy_arg, input_e|
              db_session.close
            }

            netconf_server_threads.push Thread.new {
              begin
                netconf_server.start_session([io.local_r, io.local_w])
              rescue IOError
              end
            }

            expect(db_session).to receive(:called).with(no_args).once
            expect(db_session).to receive(:close).with(no_args).twice

            io.remote_w.write hello
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

            io.remote_w.write get
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
            msg_e = REXML::Document.new(msg).root
            expect(msg_e.attributes["message-id"]).to eq "1"
            expect(msg_e.elements[1].name).to eq "root"
            expect(msg_e.elements[1].elements[1].name).to eq "result"
            expect(msg_e.elements[1].elements[1].text).to eq "dummy arg"

            io.remote_w.write close_session
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
            msg_e = REXML::Document.new(msg).root
            expect(msg_e.attributes["message-id"]).to eq "2"
            expect(msg_e.elements[1].name).to eq "ok"

            io.remote_w.close_write rescue nil
            io.remote_r.close_read  rescue nil

            expect(io.local_w.closed?).to be true
            expect(io.local_r.closed?).to be true
          end
        end
      end
    end

    describe "urn:ietf:params:netconf:capability:notification:1.0" do
      let(:now){ DateTime.now }
      let(:close_session_msg_id){ "100" }
      let(:close_session){ <<-EOB
        <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{close_session_msg_id}">
          <close-session />
        </rpc>
        ]]>]]>
        EOB
      }

      before :example do
        datastore.oper_proc("close-session"){ |db, input_e|
          # do nothing
        }

        netconf_server_threads.push Thread.new {
          begin
            netconf_server.start_session([io.local_r, io.local_w])
          rescue IOError
          end
        }

        netconf_server_threads.push Thread.new {
          begin
            netconf_server.start_session([io2.local_r, io2.local_w])
          rescue IOError
          end
        }
      end

      context "when notification:1.0 is not enabled" do
        let(:hello){ <<-EOB
          <hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
            <capabilities>
              <capability>urn:ietf:params:netconf:base:1.0</capability>
            </capabilities>
          </hello>
          ]]>]]>
          EOB
        }

        context "when receives create-subscription" do
          let(:create_subscription_msg_id){ "10" }
          let(:create_subscription){ <<-EOB
            <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
              <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                <stream>NETCONF</stream>
              </create-subscription>
            </rpc>
            ]]>]]>
            EOB
          }

          it "replies rpc-error for create-subscription message" do
            io.remote_w.write hello
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

            io.remote_w.write create_subscription
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
            msg_e = REXML::Document.new(msg).root
            expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
            expect(msg_e.elements[1].name).to eq "rpc-error"

            io.remote_w.write close_session
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
            msg_e = REXML::Document.new(msg).root
            expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
            expect(msg_e.elements[1].name).to eq "ok"

            io.remote_w.close_write rescue nil
            io.remote_r.close_read  rescue nil

            expect(io.local_w.closed?).to be true
            expect(io.local_r.closed?).to be true
          end
        end
      end

      context "when notification:1.0 is enabled" do
        let(:hello){ <<-'EOB'
          <hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
            <capabilities>
              <capability>urn:ietf:params:netconf:base:1.0</capability>
              <capability>urn:ietf:params:netconf:capability:notification:1.0</capability>
            </capabilities>
          </hello>
          ]]>]]>
          EOB
        }

        context "when create-subscription with no stream" do
          let(:create_subscription_msg_id){ "10" }
          let(:create_subscription){ <<-EOB
            <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
              <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
              </create-subscription>
            </rpc>
            ]]>]]>
            EOB
          }

          before :example do
            datastore.oper_proc("create-subscription"){ |db, input_e|
              []
            }
          end

          it "accepts the create-subscription message as its stream is NETCONF" do
            io.remote_w.write hello
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

            io.remote_w.write create_subscription
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
            msg_e = REXML::Document.new(msg).root
            expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
            expect(msg_e.elements[1].name).to eq "ok"

            event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
            netconf_server.send_notification now.rfc3339, event

            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
            msg_e = REXML::Document.new(msg).root
            expect(msg_e.elements[1].name).to eq "eventTime"
            expect(msg_e.elements[1].text).to eq now.rfc3339
            expect(msg_e.elements[2].name).to eq "testEvent"
            expect(msg_e.elements[2].namespace).to eq "testns"
            expect(msg_e.elements[2].elements[1].name).to eq "event"
            expect(msg_e.elements[2].elements[1].text).to eq "test event"

            io.remote_w.write close_session
            msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
            msg_e = REXML::Document.new(msg).root
            expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
            expect(msg_e.elements[1].name).to eq "ok"

            io.remote_w.close_write rescue nil
            io.remote_r.close_read  rescue nil

            expect(io.local_w.closed?).to be true
            expect(io.local_r.closed?).to be true
          end
        end

        context "when create-subscription with NETCONF stream" do
          context "with no startTime and no stopTime" do
            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>NETCONF</stream>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            context "when the stream doesn't support replay (NETCONF stream doesn't support replay by default)" do
              context "when datastore.oper_proc('create-subscription') raises an Exception" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    raise
                  }
                end

                it "replies rpc-error for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "rpc-error"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is invalid" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    "invalid"
                  }
                end

                it "replies ok for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is valid" do
                let(:event_time_1){ (now.to_time - 10).to_datetime }

                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    event_1 = "<testEvent xmlns='testns'><event>test event 1</event></testEvent>"
                    [
                      [event_time_1.rfc3339, event_1],
                    ]
                  }
                end

                it "replies ok for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end
            end

            context "when the stream supports replay" do
              before :example do
                netconf_server.notification_stream("NETCONF", replay_support: true)
              end

              context "when datastore.oper_proc('create-subscription') raises an Exception" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    raise
                  }
                end

                it "replies rpc-error for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "rpc-error"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is invalid" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    "invalid"
                  }
                end

                it "replies ok for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is valid" do
                let(:event_time_1){ (now.to_time - 7).to_datetime }

                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    event_1 = "<testEvent xmlns='testns'><event>test event 1</event></testEvent>"
                    [
                      [event_time_1.rfc3339, event_1],
                    ]
                  }
                end

                it "replies ok for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end
            end
          end

          context "with startTime and no stopTime" do
            let(:start_time){ (now.to_time - 5).to_datetime }
            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>NETCONF</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            context "when the stream doesn't support replay" do
              before :example do
                netconf_server.notification_stream("NETCONF", replay_support: false)

                datastore.oper_proc("create-subscription"){ |db, input_e|
                  []
                }
              end

              it "replies rpc-error" do
                io.remote_w.write hello
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                io.remote_w.write create_subscription
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                expect(msg_e.elements[1].name).to eq "rpc-error"

                event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                netconf_server.send_notification now.rfc3339, event

                io.remote_w.write close_session
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                expect(msg_e.elements[1].name).to eq "ok"

                io.remote_w.close_write rescue nil
                io.remote_r.close_read  rescue nil

                expect(io.local_w.closed?).to be true
                expect(io.local_r.closed?).to be true
              end
            end

            context "when the stream supports replay" do
              before :example do
                netconf_server.notification_stream("NETCONF", replay_support: true)
              end

              context "when datastore.oper_proc('create-subscription') is invalid" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    "invalid"
                  }
                end

                it "replies ok and sends no replay notifications and then sends replayComplete" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[2].name).to eq "replayComplete"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is valid" do
                let(:event_time_1){ (now.to_time - 7).to_datetime }
                let(:event_time_2){ (now.to_time - 3).to_datetime }
                let(:event_time_3){ (now.to_time - 1).to_datetime }

                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    event_1 = "<testEvent xmlns='testns'><event>test event 1</event></testEvent>"
                    event_2 = "<testEvent xmlns='testns'><event>test event 2</event></testEvent>"
                    event_3 = "<testEvent xmlns='testns'><event>test event 3</event></testEvent>"
                    [
                      [event_time_1.rfc3339, event_1],
                      [event_time_2.rfc3339, event_2],
                      [event_time_3.rfc3339, event_3],
                    ]
                  }
                end

                it "replies ok for create-subscription and sends replay notifications and then sends replyComplete" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[2].name).to eq "replayComplete"

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end
            end
          end

          context "with startTime and stopTime" do
            let(:start_time){ (now.to_time - 5).to_datetime }
            let(:stop_time ){ (now.to_time + 2).to_datetime }
            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>NETCONF</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                  <stopTime>#{stop_time.rfc3339}</stopTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            context "when the stream doesn't support replay" do
              before :example do
                netconf_server.notification_stream("NETCONF", replay_support: false)

                datastore.oper_proc("create-subscription"){ |db, input_e|
                  []
                }
              end

              it "replies rpc-error" do
                io.remote_w.write hello
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                io.remote_w.write create_subscription
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                expect(msg_e.elements[1].name).to eq "rpc-error"

                event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                netconf_server.send_notification now.rfc3339, event

                io.remote_w.write close_session
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                expect(msg_e.elements[1].name).to eq "ok"

                io.remote_w.close_write rescue nil
                io.remote_r.close_read  rescue nil

                expect(io.local_w.closed?).to be true
                expect(io.local_r.closed?).to be true
              end
            end

            context "when the stream supports replay" do
              before :example do
                netconf_server.notification_stream("NETCONF", replay_support: true)
              end

              context "when stopTime is earlier than startTime" do
                let(:stop_time ){ (now.to_time - 10).to_datetime }

                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    []
                  }
                end

                it "replies rpc-error" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "rpc-error"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is invalid" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    "invalid"
                  }
                end

                it "replies ok and sends no replay notifications and then sends replayComplete" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[2].name).to eq "replayComplete"

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is valid" do
                let(:event_time_1){ (now.to_time - 7).to_datetime }
                let(:event_time_2){ (now.to_time - 3).to_datetime }
                let(:event_time_3){ (now.to_time - 1).to_datetime }

                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    event_1 = "<testEvent xmlns='testns'><event>test event 1</event></testEvent>"
                    event_2 = "<testEvent xmlns='testns'><event>test event 2</event></testEvent>"
                    event_3 = "<testEvent xmlns='testns'><event>test event 3</event></testEvent>"
                    [
                      [event_time_1.rfc3339, event_1],
                      [event_time_2.rfc3339, event_2],
                      [event_time_3.rfc3339, event_3],
                    ]
                  }
                end

                context "when stopTime comes before close-session" do
                  it "sends notificationComplete event and no more events" do
                    io.remote_w.write hello
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                    io.remote_w.write create_subscription
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                    expect(msg_e.elements[1].name).to eq "ok"

                    event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                    netconf_server.send_notification now.rfc3339, event

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[2].name).to eq "replayComplete"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq now.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event"

                    sleep 3

                    event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                    netconf_server.send_notification now.rfc3339, event

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[2].name).to eq "notificationComplete"

                    io.remote_w.write close_session
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                    expect(msg_e.elements[1].name).to eq "ok"

                    io.remote_w.close_write rescue nil
                    io.remote_r.close_read  rescue nil

                    expect(io.local_w.closed?).to be true
                    expect(io.local_r.closed?).to be true
                  end
                end

                context "when stopTime doesn't come before close-session" do
                  it "doesn't send notificationComplete event" do
                    io.remote_w.write hello
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                    io.remote_w.write create_subscription
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                    expect(msg_e.elements[1].name).to eq "ok"

                    event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                    netconf_server.send_notification now.rfc3339, event

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[2].name).to eq "replayComplete"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq now.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event"

                    io.remote_w.write close_session
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                    expect(msg_e.elements[1].name).to eq "ok"

                    io.remote_w.close_write rescue nil
                    io.remote_r.close_read  rescue nil

                    expect(io.local_w.closed?).to be true
                    expect(io.local_r.closed?).to be true
                  end
                end
              end
            end
          end

          context "with no startTime and stopTime" do
            let(:stop_time ){ (now.to_time + 2).to_datetime }
            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>NETCONF</stream>
                  <stopTime>#{stop_time.rfc3339}</stopTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            context "when the stream doesn't support replay" do
              it "replies rpc-error" do
                io.remote_w.write hello
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                io.remote_w.write create_subscription
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                expect(msg_e.elements[1].name).to eq "rpc-error"

                event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                netconf_server.send_notification now.rfc3339, event

                io.remote_w.write close_session
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                expect(msg_e.elements[1].name).to eq "ok"

                io.remote_w.close_write rescue nil
                io.remote_r.close_read  rescue nil

                expect(io.local_w.closed?).to be true
                expect(io.local_r.closed?).to be true
              end
            end

            context "when the stream supports replay" do
              before :example do
                netconf_server.notification_stream("NETCONF", replay_support: true)
              end

              it "replies rpc-error" do
                io.remote_w.write hello
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                io.remote_w.write create_subscription
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                expect(msg_e.elements[1].name).to eq "rpc-error"

                event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                netconf_server.send_notification now.rfc3339, event

                io.remote_w.write close_session
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                expect(msg_e.elements[1].name).to eq "ok"

                io.remote_w.close_write rescue nil
                io.remote_r.close_read  rescue nil

                expect(io.local_w.closed?).to be true
                expect(io.local_r.closed?).to be true
              end
            end
          end
        end

        context "when create-subscription with other stream" do
          context "with no startTime and no stopTime" do
            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>other</stream>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            context "when the stream doesn't support replay" do
              before :example do
                netconf_server.notification_stream("other", replay_support: false){ true }
              end

              context "when datastore.oper_proc('create-subscription') raises an Exception" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    raise
                  }
                end

                it "replies rpc-error for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "rpc-error"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is invalid" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    "invalid"
                  }
                end

                it "replies ok for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is valid" do
                let(:event_time_1){ (now.to_time - 10).to_datetime }

                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    event_1 = "<testEvent xmlns='testns'><event>test event 1</event></testEvent>"
                    [
                      [event_time_1.rfc3339, event_1],
                    ]
                  }
                end

                it "replies ok for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end
            end

            context "when the stream supports replay" do
              before :example do
                netconf_server.notification_stream("other", replay_support: true){ true }
              end

              context "when datastore.oper_proc('create-subscription') raises an Exception" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    raise
                  }
                end

                it "replies rpc-error for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "rpc-error"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is invalid" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    "invalid"
                  }
                end

                it "replies ok for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is valid" do
                let(:event_time_1){ (now.to_time - 7).to_datetime }

                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    event_1 = "<testEvent xmlns='testns'><event>test event 1</event></testEvent>"
                    [
                      [event_time_1.rfc3339, event_1],
                    ]
                  }
                end

                it "replies ok for create-subscription" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end
            end
          end

          context "with startTime and no stopTime" do
            let(:start_time){ (now.to_time - 5).to_datetime }
            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>other</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            context "when the stream doesn't support replay" do
              before :example do
                netconf_server.notification_stream("other", replay_support: false){ true }

                datastore.oper_proc("create-subscription"){ |db, input_e|
                  []
                }
              end

              it "replies rpc-error" do
                io.remote_w.write hello
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                io.remote_w.write create_subscription
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                expect(msg_e.elements[1].name).to eq "rpc-error"

                event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                netconf_server.send_notification now.rfc3339, event

                io.remote_w.write close_session
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                expect(msg_e.elements[1].name).to eq "ok"

                io.remote_w.close_write rescue nil
                io.remote_r.close_read  rescue nil

                expect(io.local_w.closed?).to be true
                expect(io.local_r.closed?).to be true
              end
            end

            context "when the stream supports replay" do
              before :example do
                netconf_server.notification_stream("other", replay_support: true){ true }
              end

              context "when datastore.oper_proc('create-subscription') is invalid" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    "invalid"
                  }
                end

                it "replies ok and sends no replay notifications and then sends replayComplete" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[2].name).to eq "replayComplete"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is valid" do
                let(:event_time_1){ (now.to_time - 7).to_datetime }
                let(:event_time_2){ (now.to_time - 3).to_datetime }
                let(:event_time_3){ (now.to_time - 1).to_datetime }

                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    event_1 = "<testEvent xmlns='testns'><event>test event 1</event></testEvent>"
                    event_2 = "<testEvent xmlns='testns'><event>test event 2</event></testEvent>"
                    event_3 = "<testEvent xmlns='testns'><event>test event 3</event></testEvent>"
                    [
                      [event_time_1.rfc3339, event_1],
                      [event_time_2.rfc3339, event_2],
                      [event_time_3.rfc3339, event_3],
                    ]
                  }
                end

                it "replies ok for create-subscription and sends replay notifications and then sends replyComplete" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[2].name).to eq "replayComplete"

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end
            end
          end

          context "with startTime and stopTime" do
            let(:start_time){ (now.to_time - 5).to_datetime }
            let(:stop_time ){ (now.to_time + 2).to_datetime }
            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>other</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                  <stopTime>#{stop_time.rfc3339}</stopTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            context "when the stream doesn't support replay" do
              before :example do
                netconf_server.notification_stream("other", replay_support: false){ true }

                datastore.oper_proc("create-subscription"){ |db, input_e|
                  []
                }
              end

              it "replies rpc-error" do
                io.remote_w.write hello
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                io.remote_w.write create_subscription
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                expect(msg_e.elements[1].name).to eq "rpc-error"

                event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                netconf_server.send_notification now.rfc3339, event

                io.remote_w.write close_session
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                expect(msg_e.elements[1].name).to eq "ok"

                io.remote_w.close_write rescue nil
                io.remote_r.close_read  rescue nil

                expect(io.local_w.closed?).to be true
                expect(io.local_r.closed?).to be true
              end
            end

            context "when the stream supports replay" do
              before :example do
                netconf_server.notification_stream("other", replay_support: true){ true }
              end

              context "when stopTime is earlier than startTime" do
                let(:stop_time ){ (now.to_time - 10).to_datetime }

                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    []
                  }
                end

                it "replies rpc-error" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "rpc-error"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is invalid" do
                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    "invalid"
                  }
                end

                it "replies ok and sends no replay notifications and then sends replayComplete" do
                  io.remote_w.write hello
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                  io.remote_w.write create_subscription
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                  netconf_server.send_notification now.rfc3339, event

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[2].name).to eq "replayComplete"

                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.elements[1].name).to eq "eventTime"
                  expect(msg_e.elements[1].text).to eq now.rfc3339
                  expect(msg_e.elements[2].name).to eq "testEvent"
                  expect(msg_e.elements[2].namespace).to eq "testns"
                  expect(msg_e.elements[2].elements[1].name).to eq "event"
                  expect(msg_e.elements[2].elements[1].text).to eq "test event"

                  io.remote_w.write close_session
                  msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                  msg_e = REXML::Document.new(msg).root
                  expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                  expect(msg_e.elements[1].name).to eq "ok"

                  io.remote_w.close_write rescue nil
                  io.remote_r.close_read  rescue nil

                  expect(io.local_w.closed?).to be true
                  expect(io.local_r.closed?).to be true
                end
              end

              context "when datastore.oper_proc('create-subscription') is valid" do
                let(:event_time_1){ (now.to_time - 7).to_datetime }
                let(:event_time_2){ (now.to_time - 3).to_datetime }
                let(:event_time_3){ (now.to_time - 1).to_datetime }

                before :example do
                  datastore.oper_proc("create-subscription"){ |db, input_e|
                    event_1 = "<testEvent xmlns='testns'><event>test event 1</event></testEvent>"
                    event_2 = "<testEvent xmlns='testns'><event>test event 2</event></testEvent>"
                    event_3 = "<testEvent xmlns='testns'><event>test event 3</event></testEvent>"
                    [
                      [event_time_1.rfc3339, event_1],
                      [event_time_2.rfc3339, event_2],
                      [event_time_3.rfc3339, event_3],
                    ]
                  }
                end

                context "when stopTime comes before close-session" do
                  it "sends notificationComplete event and no more events" do
                    io.remote_w.write hello
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                    io.remote_w.write create_subscription
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                    expect(msg_e.elements[1].name).to eq "ok"

                    event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                    netconf_server.send_notification now.rfc3339, event

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[2].name).to eq "replayComplete"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq now.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event"

                    sleep 3

                    event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                    netconf_server.send_notification now.rfc3339, event

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[2].name).to eq "notificationComplete"

                    io.remote_w.write close_session
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                    expect(msg_e.elements[1].name).to eq "ok"

                    io.remote_w.close_write rescue nil
                    io.remote_r.close_read  rescue nil

                    expect(io.local_w.closed?).to be true
                    expect(io.local_r.closed?).to be true
                  end
                end

                context "when stopTime doesn't come before close-session" do
                  it "doesn't send notificationComplete event" do
                    io.remote_w.write hello
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                    io.remote_w.write create_subscription
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                    expect(msg_e.elements[1].name).to eq "ok"

                    event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                    netconf_server.send_notification now.rfc3339, event

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[2].name).to eq "replayComplete"

                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.elements[1].name).to eq "eventTime"
                    expect(msg_e.elements[1].text).to eq now.rfc3339
                    expect(msg_e.elements[2].name).to eq "testEvent"
                    expect(msg_e.elements[2].namespace).to eq "testns"
                    expect(msg_e.elements[2].elements[1].name).to eq "event"
                    expect(msg_e.elements[2].elements[1].text).to eq "test event"

                    io.remote_w.write close_session
                    msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                    msg_e = REXML::Document.new(msg).root
                    expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                    expect(msg_e.elements[1].name).to eq "ok"

                    io.remote_w.close_write rescue nil
                    io.remote_r.close_read  rescue nil

                    expect(io.local_w.closed?).to be true
                    expect(io.local_r.closed?).to be true
                  end
                end
              end
            end
          end

          context "with no startTime and stopTime" do
            let(:stop_time ){ (now.to_time + 2).to_datetime }
            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>other</stream>
                  <stopTime>#{stop_time.rfc3339}</stopTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            context "when the stream doesn't support replay" do
              before :example do
                netconf_server.notification_stream("other", replay_support: false){ true }
              end

              it "replies rpc-error" do
                io.remote_w.write hello
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                io.remote_w.write create_subscription
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                expect(msg_e.elements[1].name).to eq "rpc-error"

                event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                netconf_server.send_notification now.rfc3339, event

                io.remote_w.write close_session
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                expect(msg_e.elements[1].name).to eq "ok"

                io.remote_w.close_write rescue nil
                io.remote_r.close_read  rescue nil

                expect(io.local_w.closed?).to be true
                expect(io.local_r.closed?).to be true
              end
            end

            context "when the stream supports replay" do
              before :example do
                netconf_server.notification_stream("other", replay_support: true){ true }
              end

              it "replies rpc-error" do
                io.remote_w.write hello
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

                io.remote_w.write create_subscription
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
                expect(msg_e.elements[1].name).to eq "rpc-error"

                event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
                netconf_server.send_notification now.rfc3339, event

                io.remote_w.write close_session
                msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
                msg_e = REXML::Document.new(msg).root
                expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
                expect(msg_e.elements[1].name).to eq "ok"

                io.remote_w.close_write rescue nil
                io.remote_r.close_read  rescue nil

                expect(io.local_w.closed?).to be true
                expect(io.local_r.closed?).to be true
              end
            end
          end
        end

        context "when multiple create-subscriptions (NETCONF and other streams)" do
          let(:event_time_1){ (now.to_time - 7).to_datetime }
          let(:event_time_2){ (now.to_time - 3).to_datetime }
          let(:event_time_3){ (now.to_time - 1).to_datetime }

          before :example do
            netconf_server.notification_stream("NETCONF", replay_support: true){ true }
            netconf_server.notification_stream("other",   replay_support: true){ true }

            datastore.oper_proc("create-subscription"){ |db, input_e|
              event_1 = "<testEvent xmlns='testns'><event>test event 1</event></testEvent>"
              event_2 = "<testEvent xmlns='testns'><event>test event 2</event></testEvent>"
              event_3 = "<testEvent xmlns='testns'><event>test event 3</event></testEvent>"
              [
                [event_time_1.rfc3339, event_1],
                [event_time_2.rfc3339, event_2],
                [event_time_3.rfc3339, event_3],
              ]
            }
          end

          context "all clients have NETCONF subscription" do
            let(:start_time){ (now.to_time - 5).to_datetime }

            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>NETCONF</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            it "sends per-subscription notifications" do
              io.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io2.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io.remote_w.write create_subscription
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write create_subscription
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
              netconf_server.send_notification now.rfc3339, event

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event"

              io.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io.remote_w.close_write rescue nil
              io.remote_r.close_read  rescue nil

              io2.remote_w.close_write rescue nil
              io2.remote_r.close_read  rescue nil

              expect(io.local_w.closed?).to be true
              expect(io.local_r.closed?).to be true

              expect(io2.local_w.closed?).to be true
              expect(io2.local_r.closed?).to be true
            end
          end

          context "all clients have other subscription" do
            let(:start_time){ (now.to_time - 5).to_datetime }

            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>other</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            it "sends per-subscription notifications" do
              io.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io2.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io.remote_w.write create_subscription
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write create_subscription
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
              netconf_server.send_notification now.rfc3339, event

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event"

              io.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io.remote_w.close_write rescue nil
              io.remote_r.close_read  rescue nil

              io2.remote_w.close_write rescue nil
              io2.remote_r.close_read  rescue nil

              expect(io.local_w.closed?).to be true
              expect(io.local_r.closed?).to be true

              expect(io2.local_w.closed?).to be true
              expect(io2.local_r.closed?).to be true
            end
          end

          context "client1 has NETCONF and client2 has other subscription" do
            let(:start_time){ (now.to_time - 5).to_datetime }

            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>NETCONF</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }
            let(:create_subscription2){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>other</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            it "sends per-subscription notifications" do
              io.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io2.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io.remote_w.write create_subscription
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write create_subscription2
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              event = "<testEvent xmlns='testns'><event>test event</event></testEvent>"
              netconf_server.send_notification now.rfc3339, event

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "testns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "test event"

              io.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io.remote_w.close_write rescue nil
              io.remote_r.close_read  rescue nil

              io2.remote_w.close_write rescue nil
              io2.remote_r.close_read  rescue nil

              expect(io.local_w.closed?).to be true
              expect(io.local_r.closed?).to be true

              expect(io2.local_w.closed?).to be true
              expect(io2.local_r.closed?).to be true
            end
          end
        end

        context "when multiple create-subscriptions (no duplicate streams)" do
          let(:event_time_1){ (now.to_time - 7).to_datetime }
          let(:event_time_2){ (now.to_time - 3).to_datetime }
          let(:event_time_3){ (now.to_time - 1).to_datetime }

          before :example do
            netconf_server.notification_stream("stream1", replay_support: true){ |e| e.elements[2].namespace == 'stream1ns' }
            netconf_server.notification_stream("stream2", replay_support: true){ |e| e.elements[2].namespace == 'stream2ns' }

            datastore.oper_proc("create-subscription"){ |db, input_e|
              stream1_event_1 = "<testEvent xmlns='stream1ns'><event>stream1 event 1</event></testEvent>"
              stream1_event_2 = "<testEvent xmlns='stream1ns'><event>stream1 event 2</event></testEvent>"
              stream1_event_3 = "<testEvent xmlns='stream1ns'><event>stream1 event 3</event></testEvent>"
              stream2_event_1 = "<testEvent xmlns='stream2ns'><event>stream2 event 1</event></testEvent>"
              stream2_event_2 = "<testEvent xmlns='stream2ns'><event>stream2 event 2</event></testEvent>"
              stream2_event_3 = "<testEvent xmlns='stream2ns'><event>stream2 event 3</event></testEvent>"
              [
                [event_time_1.rfc3339, stream1_event_1],
                [event_time_1.rfc3339, stream2_event_1],
                [event_time_2.rfc3339, stream1_event_2],
                [event_time_2.rfc3339, stream2_event_2],
                [event_time_3.rfc3339, stream1_event_3],
                [event_time_3.rfc3339, stream2_event_3],
              ]
            }
          end

          context "all clients have stream1 subscription" do
            let(:start_time){ (now.to_time - 5).to_datetime }

            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>stream1</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            it "sends per-subscription notifications" do
              io.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io2.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io.remote_w.write create_subscription
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write create_subscription
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              event = "<testEvent xmlns='stream1ns'><event>stream1 event</event></testEvent>"
              netconf_server.send_notification now.rfc3339, event

              event = "<testEvent xmlns='stream2ns'><event>stream2 event</event></testEvent>"
              netconf_server.send_notification now.rfc3339, event

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream1ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream1 event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream1ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream1 event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream1ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream1 event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream1ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream1 event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream1ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream1 event"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream1ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream1 event"

              io.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io.remote_w.close_write rescue nil
              io.remote_r.close_read  rescue nil

              io2.remote_w.close_write rescue nil
              io2.remote_r.close_read  rescue nil

              expect(io.local_w.closed?).to be true
              expect(io.local_r.closed?).to be true

              expect(io2.local_w.closed?).to be true
              expect(io2.local_r.closed?).to be true
            end
          end

          context "all clients have stream2 subscription" do
            let(:start_time){ (now.to_time - 5).to_datetime }

            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>stream2</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            it "sends per-subscription notifications" do
              io.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io2.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io.remote_w.write create_subscription
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write create_subscription
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              event = "<testEvent xmlns='stream1ns'><event>stream1 event</event></testEvent>"
              netconf_server.send_notification now.rfc3339, event

              event = "<testEvent xmlns='stream2ns'><event>stream2 event</event></testEvent>"
              netconf_server.send_notification now.rfc3339, event

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream2ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream2 event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream2ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream2 event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream2ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream2 event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream2ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream2 event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream2ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream2 event"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream2ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream2 event"

              io.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io.remote_w.close_write rescue nil
              io.remote_r.close_read  rescue nil

              io2.remote_w.close_write rescue nil
              io2.remote_r.close_read  rescue nil

              expect(io.local_w.closed?).to be true
              expect(io.local_r.closed?).to be true

              expect(io2.local_w.closed?).to be true
              expect(io2.local_r.closed?).to be true
            end
          end

          context "client1 has stream1 and client2 has stream2 subscription" do
            let(:start_time){ (now.to_time - 5).to_datetime }

            let(:create_subscription_msg_id){ "10" }
            let(:create_subscription){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>stream1</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }
            let(:create_subscription2){ <<-EOB
              <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="#{create_subscription_msg_id}">
                <create-subscription xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
                  <stream>stream2</stream>
                  <startTime>#{start_time.rfc3339}</startTime>
                </create-subscription>
              </rpc>
              ]]>]]>
              EOB
            }

            it "sends per-subscription notifications" do
              io.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io2.remote_w.write hello
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")

              io.remote_w.write create_subscription
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write create_subscription2
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq create_subscription_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              event = "<testEvent xmlns='stream1ns'><event>stream1 event</event></testEvent>"
              netconf_server.send_notification now.rfc3339, event

              event = "<testEvent xmlns='stream2ns'><event>stream2 event</event></testEvent>"
              netconf_server.send_notification now.rfc3339, event

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream1ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream1 event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream1ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream1 event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_2.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream2ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream2 event 2"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq event_time_3.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream2ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream2 event 3"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[2].name).to eq "replayComplete"

              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream1ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream1 event"

              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.elements[1].name).to eq "eventTime"
              expect(msg_e.elements[1].text).to eq now.rfc3339
              expect(msg_e.elements[2].name).to eq "testEvent"
              expect(msg_e.elements[2].namespace).to eq "stream2ns"
              expect(msg_e.elements[2].elements[1].name).to eq "event"
              expect(msg_e.elements[2].elements[1].text).to eq "stream2 event"

              io.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io2.remote_w.write close_session
              msg = ""; msg = Timeout.timeout(1){ msg + io2.remote_r.readpartial(1) } until msg.end_with?("]]>]]>")
              msg_e = REXML::Document.new(msg).root
              expect(msg_e.attributes["message-id"]).to eq close_session_msg_id
              expect(msg_e.elements[1].name).to eq "ok"

              io.remote_w.close_write rescue nil
              io.remote_r.close_read  rescue nil

              io2.remote_w.close_write rescue nil
              io2.remote_r.close_read  rescue nil

              expect(io.local_w.closed?).to be true
              expect(io.local_r.closed?).to be true

              expect(io2.local_w.closed?).to be true
              expect(io2.local_r.closed?).to be true
            end
          end
        end
      end
    end
  end
end
