# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Error::RpcErrorable do
  let(:tag){ 'error' }
  let(:types){ ['transport', 'rpc', 'protocol', 'application'] }
  let(:severities){ ['error'] }
  let(:rpc_error_xml_to_s){ error.to_rpc_error.to_s }
  let(:expect_xml_to_s){ REXML::Document.new(expect_xml_str, {:ignore_whitespace_nodes => :all}).root.to_s }

  describe "#initialize" do
    describe "with non-empty INFO" do
      let(:infos){ ['bad-attribute', 'bad-element'] }

      describe "with type and severity" do
        let(:error){
          klass = Class.new(HrrRbNetconf::Server::Error){ include HrrRbNetconf::Server::Error::RpcErrorable }
          klass.const_set :TAG,      tag
          klass.const_set :TYPE,     types
          klass.const_set :SEVERITY, severities
          klass.const_set :INFO,     infos
          klass.new(type, severity)
        }

        describe "with valid type and valid severity" do
          let(:type){ 'protocol' }
          let(:severity){ 'error' }

          it "does not raise error" do
            expect{ error }.to raise_error ArgumentError
          end
        end

        describe "with valid type and invalid severity" do
          let(:type){ 'protocol' }
          let(:severity){ 'invalid' }

          it "raises error" do
            expect{ error }.to raise_error ArgumentError
          end
        end

        describe "with invalid type and valid severity" do
          let(:type){ 'invalid' }
          let(:severity){ 'error' }

          it "raises error" do
            expect{ error }.to raise_error ArgumentError
          end
        end

        describe "with invalid type and invalid severity" do
          let(:type){ 'invalid' }
          let(:severity){ 'invalid' }

          it "raises error" do
            expect{ error }.to raise_error ArgumentError
          end
        end
      end

      describe "with type, severity, and info" do
        let(:error){
          klass = Class.new(HrrRbNetconf::Server::Error){ include HrrRbNetconf::Server::Error::RpcErrorable }
          klass.const_set :TAG,      tag
          klass.const_set :TYPE,     types
          klass.const_set :SEVERITY, severities
          klass.const_set :INFO,     infos
          klass.new(type, severity, info: info)
        }

        describe "with valid type, valid severity, and valid info" do
          let(:type){ 'protocol' }
          let(:severity){ 'error' }
          let(:info){ {'bad-attribute' => 'bad-attr', 'bad-element' => 'bad-elem'} }
          let(:expect_xml_str){ <<-EOB
            <rpc-error>
              <error-tag>#{tag}</error-tag>
              <error-type>#{type}</error-type>
              <error-severity>#{severity}</error-severity>
              <error-info>
                <bad-attribute>#{info['bad-attribute']}</bad-attribute>
                <bad-element>#{info['bad-element']}</bad-element>
              </error-info>
            </rpc-error>
            EOB
          }

          it "does not raise error" do
            expect{ error }.not_to raise_error
            expect(rpc_error_xml_to_s).to eq expect_xml_to_s
          end
        end

        describe "with valid type, valid severity, and invalid info" do
          let(:type){ 'protocol' }
          let(:severity){ 'error' }

          describe "when info is not a kind of Hash" do
            let(:info){ 'invalid' }

            it "raises error" do
              expect{ error }.to raise_error ArgumentError
            end
          end

          describe "when info doesn't have required keys" do
            let(:info){ {'bad-attribute' => 'bad-attr'} }

            it "raises error" do
              expect{ error }.to raise_error ArgumentError
            end
          end
        end
      end

      describe "with type, severity, info, and others" do
        let(:error){
          klass = Class.new(HrrRbNetconf::Server::Error){ include HrrRbNetconf::Server::Error::RpcErrorable }
          klass.const_set :TAG,      tag
          klass.const_set :TYPE,     types
          klass.const_set :SEVERITY, severities
          klass.const_set :INFO,     infos
          klass.new(type, severity, info: info, app_tag: app_tag, path: path, message: message)
        }

        describe "with valid type, valid severity, and valid info" do
          let(:type){ 'protocol' }
          let(:severity){ 'error' }
          let(:info){ {'bad-attribute' => 'bad-attr', 'bad-element' => 'bad-elem'} }

          describe "with valid app_tag" do
            let(:app_tag){ 'app-tag' }

            describe "with valid path, and valid message" do
              describe "when path is a kind of Hash without attributes" do
                let(:path){ {'value' => '/'} }
                let(:message){ {'value' => 'message', 'attributes' => {'xml:lang' => 'en'}} }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <bad-attribute>#{info['bad-attribute']}</bad-attribute>
                      <bad-element>#{info['bad-element']}</bad-element>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path>#{path['value']}</error-path>
                    <error-message #{message['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{message['value']}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end

              describe "when path is a kind of Hash with attributes" do
                let(:path){ {'value' => '/', 'attributes' => {'xmlns' => 'namespace'}} }
                let(:message){ {'value' => 'message', 'attributes' => {'xml:lang' => 'en'}} }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <bad-attribute>#{info['bad-attribute']}</bad-attribute>
                      <bad-element>#{info['bad-element']}</bad-element>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path #{path['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{path['value']}</error-path>
                    <error-message #{message['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{message['value']}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end

              describe "when path is not a kind of Hash" do
                let(:path){ '/' }
                let(:message){ {'value' => 'message', 'attributes' => {'xml:lang' => 'en'}} }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <bad-attribute>#{info['bad-attribute']}</bad-attribute>
                      <bad-element>#{info['bad-element']}</bad-element>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path>#{path}</error-path>
                    <error-message #{message['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{message['value']}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end

              describe "when message is a kind of Hash with attributes with xml:lang key" do
                let(:path){ {'value' => '/'} }
                let(:message){ {'value' => 'message', 'attributes' => {'xml:lang' => 'ja'}} }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <bad-attribute>#{info['bad-attribute']}</bad-attribute>
                      <bad-element>#{info['bad-element']}</bad-element>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path>#{path['value']}</error-path>
                    <error-message #{message['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{message['value']}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end

              describe "when message is a kind of Hash without attributes with xml:lang key" do
                let(:path){ {'value' => '/'} }
                let(:message){ {'value' => 'message', 'attributes' => {'other-key' => 'other-value'}} }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <bad-attribute>#{info['bad-attribute']}</bad-attribute>
                      <bad-element>#{info['bad-element']}</bad-element>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path>#{path['value']}</error-path>
                    <error-message xml:lang="en" #{message['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{message['value']}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end

              describe "when message is not a kind of Hash" do
                let(:path){ {'value' => '/'} }
                let(:message){ 'message' }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <bad-attribute>#{info['bad-attribute']}</bad-attribute>
                      <bad-element>#{info['bad-element']}</bad-element>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path>#{path['value']}</error-path>
                    <error-message xml:lang="en">#{message}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end
            end

            describe "with invalid path, and valid message" do
              describe "when path is a kind of Hash, but doesn't have value key" do
                let(:path){ {'other' => '/'} }
                let(:message){ {'value' => 'message', 'attributes' => {'xml:lang' => 'en'}} }

                it "raises error" do
                  expect{ error }.to raise_error ArgumentError
                end
              end

              describe "when message is a kind of Hash, but doesn't have value key" do
                let(:path){ {'value' => '/'} }
                let(:message){ {'other' => 'message', 'attributes' => {'xml:lang' => 'en'}} }

                it "does not raise error" do
                  expect{ error }.to raise_error ArgumentError
                end
              end
            end
          end
        end
      end
    end

    describe "with empty INFO" do
      let(:infos){ [] }

      describe "with type and severity" do
        let(:error){
          klass = Class.new(HrrRbNetconf::Server::Error){ include HrrRbNetconf::Server::Error::RpcErrorable }
          klass.const_set :TAG,      tag
          klass.const_set :TYPE,     types
          klass.const_set :SEVERITY, severities
          klass.const_set :INFO,     infos
          klass.new(type, severity)
        }

        describe "with valid type and valid severity" do
          let(:type){ 'protocol' }
          let(:severity){ 'error' }
          let(:expect_xml_str){ <<-EOB
            <rpc-error>
              <error-tag>#{tag}</error-tag>
              <error-type>#{type}</error-type>
              <error-severity>#{severity}</error-severity>
            </rpc-error>
            EOB
          }

          it "does not raise error" do
            expect{ error }.not_to raise_error
            expect(rpc_error_xml_to_s).to eq expect_xml_to_s
          end
        end

        describe "with valid type and invalid severity" do
          let(:type){ 'protocol' }
          let(:severity){ 'invalid' }

          it "raises error" do
            expect{ error }.to raise_error ArgumentError
          end
        end

        describe "with invalid type and valid severity" do
          let(:type){ 'invalid' }
          let(:severity){ 'error' }

          it "raises error" do
            expect{ error }.to raise_error ArgumentError
          end
        end

        describe "with invalid type and invalid severity" do
          let(:type){ 'invalid' }
          let(:severity){ 'invalid' }

          it "raises error" do
            expect{ error }.to raise_error ArgumentError
          end
        end
      end

      describe "with type, severity, and info" do
        let(:error){
          klass = Class.new(HrrRbNetconf::Server::Error){ include HrrRbNetconf::Server::Error::RpcErrorable }
          klass.const_set :TAG,      tag
          klass.const_set :TYPE,     types
          klass.const_set :SEVERITY, severities
          klass.const_set :INFO,     infos
          klass.new(type, severity, info: info)
        }

        describe "with valid type, valid severity, and valid info" do
          let(:type){ 'protocol' }
          let(:severity){ 'error' }
          let(:info){ {'any-key' => 'any-value'} }
          let(:expect_xml_str){ <<-EOB
            <rpc-error>
              <error-tag>#{tag}</error-tag>
              <error-type>#{type}</error-type>
              <error-severity>#{severity}</error-severity>
              <error-info>
                <any-key>#{info['any-key']}</any-key>
              </error-info>
            </rpc-error>
            EOB
          }

          it "does not raise error" do
            expect{ error }.not_to raise_error
            expect(rpc_error_xml_to_s).to eq expect_xml_to_s
          end
        end

        describe "with valid type, valid severity, and any info that is not a kind of Hash" do
          let(:type){ 'protocol' }
          let(:severity){ 'error' }

          describe "when info is not a kind of Hash" do
            let(:info){ 'info' }
            let(:expect_xml_str){ <<-EOB
              <rpc-error>
                <error-tag>#{tag}</error-tag>
                <error-type>#{type}</error-type>
                <error-severity>#{severity}</error-severity>
                <error-info>#{info}</error-info>
              </rpc-error>
              EOB
            }

            it "raises error" do
              expect{ error }.not_to raise_error
              expect(rpc_error_xml_to_s).to eq expect_xml_to_s
            end
          end
        end
      end

      describe "with type, severity, info, and others" do
        let(:error){
          klass = Class.new(HrrRbNetconf::Server::Error){ include HrrRbNetconf::Server::Error::RpcErrorable }
          klass.const_set :TAG,      tag
          klass.const_set :TYPE,     types
          klass.const_set :SEVERITY, severities
          klass.const_set :INFO,     infos
          klass.new(type, severity, info: info, app_tag: app_tag, path: path, message: message)
        }

        describe "with valid type, valid severity, and valid info" do
          let(:type){ 'protocol' }
          let(:severity){ 'error' }
          let(:info){ {'any-key' => 'any-value'} }

          describe "with valid app_tag" do
            let(:app_tag){ 'app-tag' }

            describe "with valid path, and valid message" do
              describe "when path is a kind of Hash without attributes" do
                let(:path){ {'value' => '/'} }
                let(:message){ {'value' => 'message', 'attributes' => {'xml:lang' => 'en'}} }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <any-key>#{info['any-key']}</any-key>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path>#{path['value']}</error-path>
                    <error-message #{message['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{message['value']}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end

              describe "when path is a kind of Hash with attributes" do
                let(:path){ {'value' => '/', 'attributes' => {'xmlns' => 'namespace'}} }
                let(:message){ {'value' => 'message', 'attributes' => {'xml:lang' => 'en'}} }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <any-key>#{info['any-key']}</any-key>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path #{path['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{path['value']}</error-path>
                    <error-message #{message['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{message['value']}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end

              describe "when path is not a kind of Hash" do
                let(:path){ '/' }
                let(:message){ {'value' => 'message', 'attributes' => {'xml:lang' => 'en'}} }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <any-key>#{info['any-key']}</any-key>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path>#{path}</error-path>
                    <error-message #{message['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{message['value']}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end

              describe "when message is a kind of Hash with attributes with xml:lang key" do
                let(:path){ {'value' => '/'} }
                let(:message){ {'value' => 'message', 'attributes' => {'xml:lang' => 'ja'}} }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <any-key>#{info['any-key']}</any-key>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path>#{path['value']}</error-path>
                    <error-message #{message['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{message['value']}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end

              describe "when message is a kind of Hash without attributes with xml:lang key" do
                let(:path){ {'value' => '/'} }
                let(:message){ {'value' => 'message', 'attributes' => {'other-key' => 'other-value'}} }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <any-key>#{info['any-key']}</any-key>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path>#{path['value']}</error-path>
                    <error-message xml:lang="en" #{message['attributes'].map{|k,v| "#{k}=\"#{v}\""}.join(' ')}>#{message['value']}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end

              describe "when message is not a kind of Hash" do
                let(:path){ {'value' => '/'} }
                let(:message){ 'message' }
                let(:expect_xml_str){ <<-EOB
                  <rpc-error>
                    <error-tag>#{tag}</error-tag>
                    <error-type>#{type}</error-type>
                    <error-severity>#{severity}</error-severity>
                    <error-info>
                      <any-key>#{info['any-key']}</any-key>
                    </error-info>
                    <error-app-tag>#{app_tag}</error-app-tag>
                    <error-path>#{path['value']}</error-path>
                    <error-message xml:lang="en">#{message}</error-message>
                  </rpc-error>
                  EOB
                }

                it "does not raise error" do
                  expect{ error }.not_to raise_error
                  expect(rpc_error_xml_to_s).to eq expect_xml_to_s
                end
              end
            end

            describe "with invalid path, and valid message" do
              describe "when path is a kind of Hash, but doesn't have value key" do
                let(:path){ {'other' => '/'} }
                let(:message){ {'value' => 'message', 'attributes' => {'xml:lang' => 'en'}} }

                it "raises error" do
                  expect{ error }.to raise_error ArgumentError
                end
              end

              describe "when message is a kind of Hash, but doesn't have value key" do
                let(:path){ {'value' => '/'} }
                let(:message){ {'other' => 'message', 'attributes' => {'xml:lang' => 'en'}} }

                it "does not raise error" do
                  expect{ error }.to raise_error ArgumentError
                end
              end
            end
          end
        end
      end
    end
  end
end
