module ApnsGatling
  class Response
    attr_reader :headers, :data

    def initialize(options={})
      @headers = options[:headers]
      @data    = options[:body]
    end

    def status
      @headers[':status'] if @headers
    end

    def ok?
      status == '200'
    end

    def data
      JSON.parse(@data) rescue @data
    end

    # TODO: error process
  end
end
