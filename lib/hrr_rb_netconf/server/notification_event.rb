# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_relaxed_xml'

module HrrRbNetconf
  class Server
    class NotificationEvent
      def initialize arg1, arg2=nil
        unless arg2
          @event_xml = case arg1
                      when HrrRbRelaxedXML::Document
                        arg1
                      else
                        HrrRbRelaxedXML::Document.new(arg2, {:ignore_whitespace_nodes => :all})
                      end
          event_time = @event_xml.elements['eventTime'].text
          @event_xml.elements['eventTime'].text = DateTime.parse(event_time).rfc3339
        else
          event_time_e = REXML::Element.new('eventTime')
          event_time_e.text = case arg1
                              when REXML::Element
                                DateTime.parse(arg1.text).rfc3339
                              else
                                DateTime.parse(arg1.to_s).rfc3339
                              end
          event_e = case arg2
                    when REXML::Document
                      arg2.root.deep_clone
                    when REXML::Element
                      arg2.deep_clone
                    else
                      REXML::Document.new(arg2, {:ignore_whitespace_nodes => :all}).root
                    end
          @event_xml = HrrRbRelaxedXML::Document.new
          @event_xml.add event_time_e
          @event_xml.add event_e
        end
      end

      def to_xml
        @event_xml
      end
    end
  end
end
