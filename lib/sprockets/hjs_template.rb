require 'tilt'
module Sprockets
  # Tilt engine class for the Hjs compiler. Depends on the `Haml` and `Eco` gem.

  class HjsTemplate < Tilt::Template
    # Check to see if HAML and Eco is loaded
    def self.engine_initialized?
      defined? ::HAML && defined? ::Eco
    end

    # Autoload eco library. If the library isn't loaded, Tilt will produce
    # a thread safetly warning. If you intend to use `.eco` files, you
    # should explicitly require it.
    def initialize_engine
      require_template_library 'eco'
    end

    def prepare
    end

    # Compile template data with HJS compiler.
    #
    # Returns a JS function definition String. The result should be
    # assigned to a JS variable.
    #
    #     # => "function(obj){...}"
    #
    def evaluate(scope, locals, &block)
      # HAML some syntax sugar
      data.force_encoding("UTF-8") if data.respond_to?(:force_encoding)
      rules = [
        {
          :regexp => /(^\s*)-\s*end$/,
          :block => proc { |arg| "#{$1}<% end %>" }
        },
        {
          :regexp => /(^\s*)-(.*?)do$/,
          :block => proc { |arg| "#{$1}=e '#{$2.strip}:' do" }
        },
        {
          :regexp => /(^\s*)-(.*$)/,
          :block => proc { |arg| $1 + "<% #{$2.strip} %>".gsub(/<% ([=-])/, '<%\1') }
        }
      ]
      rules.each do |rule|
        data.gsub!(rule[:regexp]) { |line| rule[:block].call(line) }
      end
      context = Object.new
      class << context
        include Haml::Helpers
        include ActionView::Helpers

        def e str, &block
          return "<%#{str}%>" unless block_given?
          e("#{str}") + capture_haml(&block).chomp
        end
      end
      # HAML hack and Eco compile
      Eco.compile CGI.unescapeHTML("#{Haml::Engine.new(data).render(context)}")
    end
  end
end