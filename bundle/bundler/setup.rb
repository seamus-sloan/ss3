require 'rbconfig'
module Kernel
  remove_method(:gem) if private_method_defined?(:gem)

  def gem(*)
  end

  private :gem
end
unless defined?(Gem)
  module Gem
    def self.ruby_api_version
      RbConfig::CONFIG["ruby_version"]
    end

    def self.extension_api_version
      if 'no' == RbConfig::CONFIG['ENABLE_SHARED']
        "#{ruby_api_version}-static"
      else
        ruby_api_version
      end
    end
  end
end
if Gem.respond_to?(:discover_gems_on_require=)
  Gem.discover_gems_on_require = false
else
  [::Kernel.singleton_class, ::Kernel].each do |k|
    if k.private_method_defined?(:gem_original_require)
      private_require = k.private_method_defined?(:require)
      k.send(:remove_method, :require)
      k.send(:define_method, :require, k.instance_method(:gem_original_require))
      k.send(:private, :require) if private_require
    end
  end
end
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/aws-eventstream-1.3.0/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/aws-partitions-1.1001.0/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/aws-sigv4-1.10.1/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/jmespath-1.6.2/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/aws-sdk-core-3.211.0/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/aws-sdk-kms-1.95.0/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/aws-sdk-s3-1.169.0/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/base64-0.2.0/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/cli-ui-2.2.3/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/logger-1.6.1/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/extensions/arm64-darwin-23/#{Gem.extension_api_version}/racc-1.8.1")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/racc-1.8.1/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/nokogiri-1.16.7-arm64-darwin/lib")
$:.unshift File.expand_path("#{__dir__}/../#{RUBY_ENGINE}/#{Gem.ruby_api_version}/gems/ostruct-0.6.0/lib")
