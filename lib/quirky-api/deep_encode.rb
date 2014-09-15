class Hash
  def deep_encode(encoding = 'UTF-8')
    each do |key, val|
      if val.is_a? Hash
        val.deep_encode(encoding)
      else
        if val.respond_to?(:encode)
          val = val.encode(encoding)
          val.gsub!(/\\u([0-9a-z]{4})/) { |s| [$1.to_i(16)].pack('U') }
        end
      end
    end
  end
end
