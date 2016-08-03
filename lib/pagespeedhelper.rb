require 'google/apis/pagespeedonline_v2'
require 'google/apis'
require 'logger'

class PageSpeedHelper
  attr_reader :errors
  
  Pagespeedonline = Google::Apis::PagespeedonlineV2
  
  def initialize(key, debug=false)
    @psservice = Pagespeedonline::PagespeedonlineService.new
    @psservice.key = key

    if debug
      Google::Apis.logger = Logger.new(STDERR)
      Google::Apis.logger.level = Logger::DEBUG
    end
  end

  def query(urls, secure=false, strategy="desktop")
    @errors = Array.new
    data = Array.new 
    urls = [urls] if !urls.is_a?(Array)
    urls = urls.each { |url| add_protocol_if_absent!(url, secure) }
    
    urls.each_slice(20).to_a.each do |url_list|
      data.concat send_request(url_list, strategy)
      sleep(0.5)
    end

    data
  end

  def self.parse(data)
    results = Array.new
    
    data.each do |result|
      result_hash = Hash.new
      result_hash["url"] = result.id
      result_hash["score"] = result.rule_groups["SPEED"].score
      result_hash["stats"] = Hash[result.page_stats.to_h.map{ |k, v| [k.to_s, v] }]
      
      result_hash["results"] = Hash.new
      build_rule_hash(result_hash["results"], result.formatted_results.rule_results)

      results.push(result_hash)
    end

    results
  end

  def self.build_rule_hash(hash, rule_res)
    rule_res.each do |rule, info|
      hash[rule] = Hash.new
      hash[rule]["name"] = info.localized_rule_name
      hash[rule]["impact"] = info.rule_impact

      if !info.summary.nil?
        hash[rule]["summary"] = build_summary_string!(info.summary)
      end
    end
  end
  
  def self.build_summary_string!(summary)
    if summary.to_h.key?(:args)
      summary.args.each do |arg|
        summary.format.sub!('{{' + arg.key + '}}', arg.value) if arg.key != 'LINK'
      end
    end 

    summary.format.include?(" Learn more") ? summary.format.split(" Learn more")[0] : summary.format 
  end

  private_class_method :build_rule_hash, :build_summary_string!

  private

  def send_request(urls, strategy="desktop")
    data = Array.new
    @psservice.batch do |ps|
      urls.each do |url|
        ps.run_pagespeed(url, strategy: strategy) do |result, err|
          err.nil? ? data.push(result) : @errors.push({ "url" => url, "error" => err })
        end
      end
    end
    data
  end

  def add_protocol_if_absent!(url, secure=false)  
    if !url.include? "http://" and !url.include? "https://"
      secure ? url.replace("https://" + url) : url.replace("http://" + url)
    end
  end

end
