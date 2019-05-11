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
    let(:server){ described_class.new }

    it "doesn't raise error" do
      expect { described_class.new }.not_to raise_error
    end

    it "initializes @sessions" do
      expect(server.instance_variable_get('@sessions')).to eq Hash.new
    end
  end

  describe "#allocate_session_id" do
    let(:server){ described_class.new }

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
end