require 'spec_helper'

describe Robotex do
  let(:robots) do
    <<~ROBOTS
      User-Agent: msnbot
      Crawl-Delay: 20

      User-Agent: bender
      Disallow: /my_shiny_metal_ass

      User-Agent: *
      Disallow: /login
      Disallow: /archive/ #old content
      Allow: /

      Disallow: /locked
      Allow: /locked
    ROBOTS
  end

  let(:response) do
    { body: robots, content_type: 'text/plain', status: [200, "OK"] }
  end

  before do
    FakeWeb.allow_net_connect = false
    FakeWeb.register_uri(:get, SPEC_DOMAIN + 'robots.txt', response)
  end

  describe '#initialize' do
    context 'when no arguments are supplied' do
      it 'returns a Robotex with the default user-agent' do
        Robotex.new.user_agent.should == "Robotex/#{Robotex::VERSION} (http://www.github.com/chriskite/robotex)"
      end
    end

    context 'when a user-agent is specified' do
      it 'returns a Robotex with the specified user-agent' do
        ua = 'My User Agent'
        Robotex.new(ua).user_agent.should == ua
      end
    end
  end

  describe '#allowed?' do
    context 'when the robots.txt disallows the user-agent to the url' do
      it 'returns false' do
        robotex = Robotex.new('bender')
        robotex.allowed?(SPEC_DOMAIN + 'my_shiny_metal_ass').should be_false
      end
    end

    context 'when the robots.txt disallows the user-agent to some urls, but allows this one' do
      it 'returns true' do
        robotex = Robotex.new('bender')
        robotex.allowed?(SPEC_DOMAIN + 'cigars').should be_true
      end
    end

    context 'when the robots.txt disallows any user-agent to the url' do
      it 'returns false' do
        robotex = Robotex.new
        robotex.allowed?(SPEC_DOMAIN + 'login').should be_false
      end
    end

    context 'when the robots.txt disallows and then allows the url' do
      it 'returns false' do
        robotex = Robotex.new
        robotex.allowed?(SPEC_DOMAIN + 'locked').should be_false
      end
    end

    context 'when a rule includes a comment' do
      it 'returns false' do
        robotex = Robotex.new
        robotex.allowed?(SPEC_DOMAIN + 'archive/old').should be_false
      end
    end

    context 'when the robots.txt url is redirected' do
      let(:redirection) do
        { status: [301], location: 'https://example.com/robots.txt' }
      end

      before do
        FakeWeb.register_uri(:get, SPEC_DOMAIN + 'robots.txt', redirection)
        FakeWeb.register_uri(:get, 'https://example.com/robots.txt', response)
      end

      it 'returns false' do
        robotex = Robotex.new
        robotex.allowed?(SPEC_DOMAIN + 'locked').should be_false
      end
    end
  end

  describe '#delay' do
    context 'when no Crawl-Delay is specified for the user-agent' do
      it 'returns nil' do
        robotex = Robotex.new
        robotex.delay(SPEC_DOMAIN).should be_nil
      end
    end

    context 'when Crawl-Delay is specified for the user-agent' do
      it 'returns the delay as a Fixnum' do
        robotex = Robotex.new('msnbot')
        robotex.delay(SPEC_DOMAIN).should == 20
      end
    end
  end

  describe '#sitemaps' do
    let(:robots) do
      <<~ROBOTS
        Sitemap: http://www.example.com/sitemap_1.xml
        Sitemap: http://www.example.com/sitemap_2.xml
      ROBOTS
    end

    it 'returns an array of sitemaps' do
      robotex = Robotex.new
      robotex.sitemaps(SPEC_DOMAIN).should == %w[http://www.example.com/sitemap_1.xml
                                                 http://www.example.com/sitemap_2.xml]
    end

    context 'when the sitemap url is relative' do
      let(:robots) { 'Sitemap: /relative.xml' }

      it 'returns the sitemap' do
        robotex = Robotex.new
        robotex.sitemaps(SPEC_DOMAIN).should == ['http://www.example.com/relative.xml']
      end
    end
  end
end
