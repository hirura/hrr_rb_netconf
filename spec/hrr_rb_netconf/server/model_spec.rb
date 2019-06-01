# coding: utf-8
# vim: et ts=2 sw=2

RSpec.describe HrrRbNetconf::Server::Model do
  let(:input_e){ REXML::Document.new(input_str, {:ignore_whitespace_nodes => :all}).root }

  before :example do
    model_entries.each{ |m|
      model.add *m
    }
  end

  describe "Based on functionality" do
    let(:model){ described_class.new operation }
    let(:operation){ 'my-operation' }

    describe 'Not yet added any statements' do
      let(:input_str){ <<-'EOB'
        <my-operation>
        </my-operation>
        EOB
      }
      let(:model_entries){ [] }

      it "matches to input with no children" do
        expect(model.validate input_e).to be true
      end
    end

    describe 'Not yet added any statements' do
      let(:input_str){ <<-'EOB'
        <my-operation>
          <child1 />
        </my-operation>
        EOB
      }
      let(:model_entries){ [] }

      it "doesn't match to input with children" do
        expect(model.validate input_e).to be false
      end
    end

    describe 'Not yet added any statements' do
      let(:input_str){ <<-'EOB'
        <my-operation>
          <child1 />
        </my-operation>
        EOB
      }
      let(:model_entries){ [
        [nil, ['child1'], 'container', {}],
      ] }

      it "matches to input with children" do
        expect(model.validate input_e).to be true
      end
    end

    describe 'Leaf with empty type but no input' do
      let(:input_str){ <<-'EOB'
        <my-operation>
        </my-operation>
        EOB
      }
      let(:model_entries){ [
        [nil, ['child1'], 'leaf', {'type' => 'empty'} ],
      ] }

      it "matches to input" do
        expect(model.validate input_e).to be true
      end
    end

    describe 'Leaf with empty type' do
      let(:input_str){ <<-'EOB'
        <my-operation>
          <child1 />
        </my-operation>
        EOB
      }
      let(:model_entries){ [
        [nil, ['child1'], 'leaf', {'type' => 'empty'}  ],
      ] }

      it "matches to input" do
        expect(model.validate input_e).to be true
      end
    end

    describe 'Leaf with anyxml type under container' do
      let(:input_str){ <<-'EOB'
        <my-operation>
          <child1>
            <child2>
              <child3>child3-value</child3>
            </child2>
          </child1>
        </my-operation>
        EOB
      }
      let(:model_entries){ [
        [nil, ['child1'], 'container', {}  ],
        [nil, ['child1', 'child2'], 'leaf', {'type' => 'anyxml'}  ],
      ] }

      it "matches to input" do
        expect(model.validate input_e).to be true
      end
    end

    describe 'Leaf with enumeration type' do
      describe 'Leaf has valid value' do
        let(:input_str){ <<-'EOB'
          <my-operation>
            <child1>merge</child1>
          </my-operation>
          EOB
        }
        let(:model_entries){ [
          [nil, ['child1'], 'leaf', {'type' => 'enumeration', 'enum' => ['merge', 'replace', 'none'], 'default' => 'merge'}  ],
        ] }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end

      describe 'Leaf has invalid value' do
        let(:input_str){ <<-'EOB'
          <my-operation>
            <child1>invalid</child1>
          </my-operation>
                         EOB
        }
        let(:model_entries){ [
          [nil, ['child1'], 'leaf', {'type' => 'enumeration', 'enum' => ['merge', 'replace', 'none'], 'default' => 'merge'}  ],
        ] }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end

      describe 'There is no leaf but the leaf has default value' do
        let(:input_str){ <<-'EOB'
          <my-operation>
          </my-operation>
        EOB
        }
        let(:model_entries){ [
          [nil, ['child1'], 'leaf', {'type' => 'enumeration', 'enum' => ['merge', 'replace', 'none'], 'default' => 'merge'}  ],
        ] }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end

        it "inserts leaf with default value" do
          model.validate input_e
          expect(input_e.elements['child1'].text).to eq 'merge'
        end
      end
    end

    describe 'Leaf with integer type' do
      describe 'Without range option' do
        describe 'Leaf has valid value' do
          let(:input_str){ <<-'EOB'
            <my-operation>
              <child1>100</child1>
            </my-operation>
            EOB
          }
          let(:model_entries){ [
            [nil, ['child1'], 'leaf', {'type' => 'integer'}  ],
          ] }

          it "matches to input" do
            expect(model.validate input_e).to be true
          end
        end

        describe 'Leaf has invalid value' do
          let(:input_str){ <<-'EOB'
            <my-operation>
              <child1>invalid</child1>
            </my-operation>
            EOB
          }
          let(:model_entries){ [
            [nil, ['child1'], 'leaf', {'type' => 'integer'}  ],
          ] }

          it "doesn't match to input" do
            expect(model.validate input_e).to be false
          end
        end
      end

      describe 'With range option' do
        describe 'Leaf has valid value' do
          let(:input_str){ <<-'EOB'
            <my-operation>
              <child1>-10</child1>
            </my-operation>
            EOB
          }
          let(:model_entries){ [
            [nil, ['child1'], 'leaf', {'type' => 'integer', 'range' => [-10, 10]}  ],
          ] }

          it "matches to input" do
            expect(model.validate input_e).to be true
          end
        end

        describe 'Leaf has invalid value' do
          let(:input_str){ <<-'EOB'
            <my-operation>
              <child1>100</child1>
            </my-operation>
            EOB
          }
          let(:model_entries){ [
            [nil, ['child1'], 'leaf', {'type' => 'integer', 'range' => [-10, 10]}  ],
          ] }

          it "doesn't match to input" do
            expect(model.validate input_e).to be false
          end
        end
      end

      describe 'There is no leaf but the leaf has default value' do
        let(:input_str){ <<-'EOB'
          <my-operation>
          </my-operation>
          EOB
        }
        let(:model_entries){ [
          [nil, ['child1'], 'leaf', {'type' => 'integer', 'default' => '123'}  ],
        ] }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end

        it "inserts leaf with default value" do
          model.validate input_e
          expect(input_e.elements['child1'].text).to eq '123'
        end
      end
    end

    describe 'Leaf with string type' do
      describe 'Without range option' do
        describe 'Leaf has valid value' do
          let(:input_str){ <<-'EOB'
            <my-operation>
              <child1>100</child1>
            </my-operation>
            EOB
          }
          let(:model_entries){ [
            [nil, ['child1'], 'leaf', {'type' => 'string'}  ],
          ] }

          it "matches to input" do
            expect(model.validate input_e).to be true
          end
        end

        describe "Leaf doesn't have value" do
          let(:input_str){ <<-'EOB'
            <my-operation>
              <child1></child1>
            </my-operation>
            EOB
          }
          let(:model_entries){ [
            [nil, ['child1'], 'leaf', {'type' => 'string'}  ],
          ] }

          it "doesn't match to input" do
            expect(model.validate input_e).to be false
          end
        end
      end

      describe 'There is no leaf but the leaf has default value' do
        let(:input_str){ <<-'EOB'
          <my-operation>
          </my-operation>
          EOB
        }
        let(:model_entries){ [
          [nil, ['child1'], 'leaf', {'type' => 'string', 'default' => 'abc'}  ],
        ] }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end

        it "inserts leaf with default value" do
          model.validate input_e
          expect(input_e.elements['child1'].text).to eq 'abc'
        end
      end
    end

    describe 'Choice of leaf with empty type' do
      let(:input_str){ <<-'EOB'
        <my-operation>
          <child1>
            <child2 />
          </child1>
        </my-operation>
        EOB
      }
      let(:model_entries){ [
        [nil, ['child1'],                      'container', {}],
        [nil, ['child1', 'choice1'],           'choice',    {'mandatory' => true}],
        [nil, ['child1', 'choice1', 'child2'], 'leaf',      {'type' => 'empty'}  ],
        [nil, ['child1', 'choice1', 'child3'], 'leaf',      {'type' => 'empty'}  ],
      ] }

      it "matches to input" do
        expect(model.validate input_e).to be true
      end
    end

    describe 'Validation option' do
      describe 'with correct target' do
        let(:input_str){ <<-'EOB'
        <my-operation>
          <child1>
            <child2>target</child2>
          </child1>
        </my-operation>
                         EOB
        }
        let(:model_entries){ [
          [nil,                              ['child1'],                      'container', {}],
          [nil,                              ['child1', 'choice1'],           'choice',    {'mandatory' => true}],
          [{'dummy-capability' => 'target'}, ['child1', 'choice1', 'child2'], 'leaf',      {'type' => 'string', 'validation' => proc { |cap, node| p cap; p node; cap['dummy-capability'] == node.text }}],
        ] }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end

      describe 'with correct target' do
        let(:input_str){ <<-'EOB'
        <my-operation>
          <child1>
            <child2>invalid</child2>
          </child1>
        </my-operation>
                         EOB
        }
        let(:model_entries){ [
          [nil,                              ['child1'],                      'container', {}],
          [nil,                              ['child1', 'choice1'],           'choice',    {'mandatory' => true}],
          [{'dummy-capability' => 'target'}, ['child1', 'choice1', 'child2'], 'leaf',      {'type' => 'string', 'validation' => proc { |cap, node| cap['dummy-capability'] == node.text }}],
        ] }

        it "matches to input" do
          expect(model.validate input_e).to be false
        end
      end
    end
  end

  describe "Based on capabilities" do
    describe '<get>' do
      let(:model){ described_class.new 'get' }
      let(:model_entries){ [
        [nil, ['filter'], 'leaf', {'type' => 'anyxml'}],
      ] }

      describe 'without filter' do
        let(:input_str){ <<-'EOB'
          <get>
          </get>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end

      describe 'with subtree filter' do
        let(:input_str){ <<-'EOB'
          <get>
            <filter type="subtree">
              <dummy />
            </filter>
          </get>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end

    describe '<get-config>' do
      let(:model){ described_class.new 'get-config' }
      let(:model_entries){ [
        [nil, ['source'],                               'container', {}],
        [nil, ['source', 'config-source'],              'choice',    {'mandatory' => true}],
        [nil, ['source', 'config-source', 'candidate'], 'leaf',      {'type' => 'empty'}],
        [nil, ['source', 'config-source', 'running'],   'leaf',      {'type' => 'empty'}],
        [nil, ['source', 'config-source', 'startup'],   'leaf',      {'type' => 'empty'}],
        [nil, ['filter'],                               'leaf',      {'type' => 'anyxml'}],
      ] }

      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <get-config>
            <source>
            </source>
          </get-config>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <get-config>
            <source>
              <running/>
            </source>
          </get-config>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end

      describe 'with leaf and filter' do
        let(:input_str){ <<-'EOB'
          <get-config>
            <source>
              <running/>
            </source>
            <filter type="subtree">
              <dummy />
            </filter>
          </get-config>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end

    describe '<edit-config>' do
      let(:model){ described_class.new 'edit-config' }
      let(:model_entries){ [
        [nil, ['target'],                               'container', {}],
        [nil, ['target', 'config-target'],              'choice',    {'mandatory' => true}],
        [nil, ['target', 'config-target', 'candidate'], 'leaf',      {'type' => 'empty'}],
        [nil, ['target', 'config-target', 'running'],   'leaf',      {'type' => 'empty'}],
        [nil, ['default-operation'],                    'leaf',      {'type' => 'enumeration', 'enum' => ['merge', 'replace', 'none'], 'default' => 'merge'}],
        [nil, ['test-option'],                          'leaf',      {'type' => 'enumeration', 'enum' => ['test-then-set', 'set', 'test-only'], 'default' => 'test-then-set'}],
        [nil, ['error-option'],                         'leaf',      {'type' => 'enumeration', 'enum' => ['stop-on-error', 'continue-on-error', 'rollback-on-error'], 'default' => 'stop-on-error'}],
        [nil, ['edit-content'],                         'choice',    {'mandatory' => true}],
        [nil, ['edit-content', 'config'],               'leaf',      {'type' => 'anyxml'}],
        #[nil, ['edit-content', 'url'],                  'leaf',      {'type' => 'inet:uri'}],
      ] }

      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <edit-config>
            <target>
            </target>
            <default-operation>none</default-operation>
            <config>
              <top xmlns="http://example.com/schema/1.2/config">
                <interface>
                  <name>Ethernet0/0</name>
                  <mtu>1500</mtu>
                </interface>
              </top>
            </config>
          </edit-config>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <edit-config>
            <target>
              <running/>
            </target>
            <default-operation>none</default-operation>
            <config>
              <top xmlns="http://example.com/schema/1.2/config">
                <interface>
                  <name>Ethernet0/0</name>
                  <mtu>1500</mtu>
                </interface>
              </top>
            </config>
          </edit-config>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end

    describe '<copy-config>' do
      let(:model){ described_class.new 'copy-config' }
      let(:model_entries){ [
        [nil, ['target'],                               'container', {}],
        [nil, ['target', 'config-target'],              'choice',    {'mandatory' => true}],
        [nil, ['target', 'config-target', 'candidate'], 'leaf',      {'type' => 'empty'}],
        [nil, ['target', 'config-target', 'running'],   'leaf',      {'type' => 'empty'}],
        [nil, ['target', 'config-target', 'startup'],   'leaf',      {'type' => 'empty'}],
        #[nil, ['target', 'config-target', 'url'],       'leaf',      {'type' => 'inet:uri'}],
        [nil, ['source'],                               'container', {}],
        [nil, ['source', 'config-source'],              'choice',    {'mandatory' => true}],
        [nil, ['source', 'config-source', 'candidate'], 'leaf',      {'type' => 'empty'}],
        [nil, ['source', 'config-source', 'running'],   'leaf',      {'type' => 'empty'}],
        [nil, ['source', 'config-source', 'startup'],   'leaf',      {'type' => 'empty'}],
        #[nil, ['source', 'config-source', 'url'],       'leaf',      {'type' => 'inet:uri'}],
        [nil, ['source', 'config-source', 'config'],    'leaf',      {'type' => 'anyxml'}],
      ] }

      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <copy-config>
            <source>
            </source>
            <target>
              <running />
            </target>
          </copy-config>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <copy-config>
            <source>
              <startup />
            </source>
            <target>
              <running />
            </target>
          </copy-config>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end

    describe '<delete-config>' do
      let(:model){ described_class.new 'delete-config' }
      let(:model_entries){ [
        [nil, ['target'],                               'container', {}],
        [nil, ['target', 'config-target'],              'choice',    {'mandatory' => true}],
        [nil, ['target', 'config-target', 'startup'],   'leaf',      {'type' => 'empty'}],
        #[nil, ['target', 'config-target', 'url'],       'leaf',      {'type' => 'inet:uri'}],
      ] }

      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <delete-config>
            <target>
            </target>
          </delete-config>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <delete-config>
            <target>
              <startup />
            </target>
          </delete-config>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end

    describe '<lock>' do
      let(:model){ described_class.new 'lock' }
      let(:model_entries){ [
        [nil, ['target'],                               'container', {}],
        [nil, ['target', 'config-target'],              'choice',    {'mandatory' => true}],
        [nil, ['target', 'config-target', 'candidate'], 'leaf',      {'type' => 'empty'}],
        [nil, ['target', 'config-target', 'running'],   'leaf',      {'type' => 'empty'}],
        [nil, ['target', 'config-target', 'startup'],   'leaf',      {'type' => 'empty'}],
      ] }

      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <lock>
            <target>
            </target>
          </lock>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <lock>
            <target>
              <startup />
            </target>
          </lock>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end

    describe '<unlock>' do
      let(:model){ described_class.new 'unlock' }
      let(:model_entries){ [
        [nil, ['target'],                               'container', {}],
        [nil, ['target', 'config-target'],              'choice',    {'mandatory' => true}],
        [nil, ['target', 'config-target', 'candidate'], 'leaf',      {'type' => 'empty'}],
        [nil, ['target', 'config-target', 'running'],   'leaf',      {'type' => 'empty'}],
        [nil, ['target', 'config-target', 'startup'],   'leaf',      {'type' => 'empty'}],
      ] }

      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <unlock>
            <target>
            </target>
          </unlock>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <unlock>
            <target>
              <startup />
            </target>
          </unlock>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end

    describe '<close-session>' do
      let(:model){ described_class.new 'close-session' }
      let(:model_entries){ [
        [nil, [], nil, {}],
      ] }

      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <close-session>
          </close-session>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <close-session>
            <target />
          </close-session>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end
    end

    describe '<kill-session>' do
      let(:model){ described_class.new 'kill-session' }
      let(:model_entries){ [
        [nil, ['session-id'], 'leaf', {'type' => 'integer', 'range' => [1, 2**32-1]}],
      ] }

=begin
      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <kill-session>
          </kill-session>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end
=end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <kill-session>
            <session-id>1</session-id>
          </kill-session>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end

    describe '<commit>' do
      let(:model){ described_class.new 'commit' }
      let(:model_entries){ [
        [nil, ['confirmed'],       'leaf', {'type' => 'empty'}],
        [nil, ['confirm-timeout'], 'leaf', {'type' => 'integer', 'range' => [1, 2**32-1], 'default' => '600'}],
        [nil, ['persist'],         'leaf', {'type' => 'string'}],
        [nil, ['persist-id'],      'leaf', {'type' => 'string'}],
      ] }

      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <commit>
          </commit>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <commit>
            <confirmed/>
            <confirm-timeout>120</confirm-timeout>
            <persist>IQ,d4668</persist>
          </commit>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end

    describe '<discard-changes>' do
      let(:model){ described_class.new 'discard-changes' }
      let(:model_entries){ [
        [nil, [], nil, {}],
      ] }

      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <discard-changes>
          </discard-changes>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <discard-changes>
            <target />
          </discard-changes>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end
    end

    describe '<cancel-commit>' do
      let(:model){ described_class.new 'cancel-commit' }
      let(:model_entries){ [
        [nil, ['persist-id'], 'leaf', {'type' => 'string'}],
      ] }

=begin
      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <cancel-commit>
          </cancel-commit>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end
=end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <cancel-commit>
            <persist-id>IQ,d4668</persist-id>
          </cancel-commit>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end

    describe '<validate>' do
      let(:model){ described_class.new 'validate' }
      let(:model_entries){ [
        [nil, ['source'],                               'container', {}],
        [nil, ['source', 'config-source'],              'choice',    {'mandatory' => true}],
        [nil, ['source', 'config-source', 'candidate'], 'leaf',      {'type' => 'empty'}],
        [nil, ['source', 'config-source', 'running'],   'leaf',      {'type' => 'empty'}],
        [nil, ['source', 'config-source', 'startup'],   'leaf',      {'type' => 'empty'}],
        #[nil, ['source', 'config-source', 'url'],       'leaf',      {'type' => 'inet:uri'}],
        [nil, ['source', 'config-source', 'config'],    'leaf',      {'type' => 'anyxml'}],
      ] }

      describe 'without leaf' do
        let(:input_str){ <<-'EOB'
          <validate>
            <source>
            </source>
          </validate>
          EOB
        }

        it "doesn't match to input" do
          expect(model.validate input_e).to be false
        end
      end

      describe 'with leaf' do
        let(:input_str){ <<-'EOB'
          <validate>
            <source>
              <candidate/>
            </source>
          </validate>
          EOB
        }

        it "matches to input" do
          expect(model.validate input_e).to be true
        end
      end
    end
  end
end
