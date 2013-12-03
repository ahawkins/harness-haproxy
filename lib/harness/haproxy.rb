require "harness/haproxy/version"

require 'harness'
require 'uri'
require 'net/https'
require 'csv'

module Harness
  class HAProxyGauge
    include Instrumentation

    BadResponseError = Class.new StandardError

    def initialize(url)
      @url = url
    end

    def log
      uri = URI.parse @url

      http = Net::HTTP.new uri.host, uri.port
      http.use_ssl = uri.scheme == 'https'

      request = Net::HTTP::Get.new uri.request_uri

      if uri.user || uri.password
        request.basic_auth uri.user, uri.password
      end

      response = http.request request

      if response.code.to_i != 200
        raise BadResponseError, "Server did not respond correctly! #{response.inspect}"
      end

      response = http.request request

      csv = response.body.gsub /^#\s+/, ''

      CSV.parse(csv, headers: true) do |row|
        pxname = row.field 'pxname'
        server = row.field('svname').downcase

        gauge "haproxy.#{pxname}.queue.current.#{server}", row.field('qcur').to_i
        gauge "haproxy.#{pxname}.queue.max.#{server}", row.field('qmax').to_i

        gauge "haproxy.#{pxname}.session.current.#{server}", row.field('scur').to_i
        gauge "haproxy.#{pxname}.session.max.#{server}", row.field('smax').to_i
        gauge "haproxy.#{pxname}.session.limit.#{server}", row.field('slim').to_i
        gauge "haproxy.#{pxname}.session.total.#{server}", row.field('stot').to_i

        gauge "haproxy.#{pxname}.bytes.in.#{server}", row.field('bin').to_i
        gauge "haproxy.#{pxname}.bytes.out.#{server}", row.field('bout').to_i

        gauge "haproxy.#{pxname}.request.denied.#{server}", row.field('dreq').to_i
        gauge "haproxy.#{pxname}.request.error.#{server}", row.field('ereq').to_i

        gauge "haproxy.#{pxname}.response.1xx.#{server}", row.field('hrsp_1xx').to_i
        gauge "haproxy.#{pxname}.response.2xx.#{server}", row.field('hrsp_2xx').to_i
        gauge "haproxy.#{pxname}.response.3xx.#{server}", row.field('hrsp_3xx').to_i
        gauge "haproxy.#{pxname}.response.4xx.#{server}", row.field('hrsp_4xx').to_i
        gauge "haproxy.#{pxname}.response.5xx.#{server}", row.field('hrsp_5xx').to_i

        gauge "haproxy.#{pxname}.request.rate.#{server}", row.field('req_rate').to_i
        gauge "haproxy.#{pxname}.request.max_rate.#{server}", row.field('req_rate_max').to_i

        gauge "haproxy.#{pxname}.request.total.#{server}", row.field('req_tot').to_i

        gauge "haproxy.#{pxname}.downtime.#{server}", row.field('downtime').to_i
      end
    end
  end
end

