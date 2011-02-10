namespace :scrape do
  require 'open-uri'

  #
  #
  #
  desc "Scrape the mongodb_user page for new threads"
  task :mongodb_user => :environment do

    Time.zone = 'Eastern Time (US & Canada)'  # set the timezone.. it seems that the page we fetch from google has EST times
    open_status = Status.find_by_name("Open")
    closed_status = Status.find_by_name("Closed")
    
    # get and process the google page. 
    snippet = open("http://groups.google.com/group/mongodb-user/topics?gvc=2").read
    doc     = Nokogiri::HTML(snippet)

    doc.xpath("//div[@class='maincontoutboxatt']/table").each do |table|
      table.element_children.each_with_index do |tr, index|
        tds = tr.element_children
        
        topic_elm    = tds[1].first_element_child()
        replies_elm  = tds[3].first_element_child()
        user_elm     = tds[4]
        
        if not topic_elm.has_attribute?('href')  # ignore header rows
          next
        end
        
        url         = topic_elm.get_attribute('href')
        thread      = url.match(/(\/thread|t)\/(\w+)#*$/) && $2
        subject     = topic_elm.inner_text
        replies     = ((replies_elm.inner_text || "").split("of")[1] || 1).to_i - 1        
        num_authors = (user_elm.inner_text.match(/\((\d+)/) && $1).to_i
        send_alerts = false

        article = Article.where(:thread => thread).first
        
        if (not article.nil?) # check if article already in collection
          puts "[exists] #{index - 1}\t #{thread}\t #{subject[0,40]}...\n"
          
        else # article not in collection so save it!
          puts "[create] #{index - 1}\t #{thread}\t #{subject[0,40]}...\n"
          send_alerts = true
          
          article            = Article.new
          article.domain     = "http://groups.google.com"
          article.thread     = thread
          article.url        = url && url.strip
          article.subject    = subject && subject.strip
          article.category   = nil
          article.user       = nil
          article.status     = open_status
          article.status_name= open_status.name
          article.created_at = Time.now
        end

        if article.replies != replies and article.status_id = closed_status.id     
          article.status = open_status  # re-open a closed issue, if reply count has changed
        end         
        
        article.authors   = num_authors
        
        # set authors and response times
        if article.link_time.nil? or article.first_response.nil? or article.replies != replies
          user_response_time_map = {}
          response_doc = Nokogiri::HTML(open(article.domain + (url || "")).read)
          
          response_doc.xpath("//div[@id='msgs']/div//table[@id='top']").each do |res_table|
            res_tbody = res_table.element_children.last
            res_tr = res_tbody.element_children.last 
            res_tds = res_tr.element_children
            res_time_wrapper = res_tds[2] && res_tds[2].element_children.last
            res_time_span = res_time_wrapper && res_time_wrapper.element_children.last
            response_time = res_time_span && res_time_span.inner_text 
            
            author_span_wrapper = res_tds[0] && res_tds[0].element_children.last
            author_span = author_span_wrapper && author_span_wrapper.element_children.first
            author = author_span && author_span.inner_text
            user_response_time_map[Time.zone.parse(response_time.gsub("&nbsp;",""))] = author if response_time 
          end

          # set article submission time and first response
          response_times = user_response_time_map.keys.sort!
          article.link_time ||= response_times[0]
          article.first_response ||= response_times[1]

          # set author and last-responded-by
          article.author = (user_response_time_map[response_times[0]] || "<no user found?>").strip

          article.last_responded_by = (replies > 0) ? user_response_time_map[response_times.last] : nil
        end
        
        article.replies   = replies
        update_article(article, send_alerts)
      end
    end

  end # of mongodb_user task
  
  
  
  #
  #
  #
  desc "Scrape the stackoverflow page (tagged with mongodb) for new threads"
  task :stackoverflow => :environment do
    
    sof_key = "key=#{SETTINGS_10GEN[:sof_key] || ""}"
    url_prefix = "http://api.stackoverflow.com/1.0"
    Time.zone = 'Pacific Time (US & Canada)'
    
    open_status = Status.find_by_name("Open")
    closed_status = Status.find_by_name("Closed")
    
    # get and process the stackoverflow page.
    snippet = open("#{url_prefix}/search?tagged=mongodb&sort=activity&pagesize=30&#{sof_key}").read
    doc = JSON.parse(Zlib::GzipReader.new(StringIO.new(snippet)).read)
    
    questions = doc["questions"]
    questions.each_with_index do |question, index|

      subject     = question["title"]
      thread      = question["question_id"].to_s 
      url         = "/questions/#{thread}"
      replies     = question["answer_count"]
      send_alerts = false

      article = Article.find_by_thread(thread)
      
      if (not article.nil?) # check if article already in collection
        puts "[exists] #{index + 1}\t #{thread}\t #{subject[0,40]}...\n"
        
      else # article not in collection so save it!
        puts "[create] #{index + 1}\t #{thread}\t #{subject[0,40]}...\n"
        send_alerts = true
        
        article            = Article.new
        article.domain     = "http://stackoverflow.com"
        article.thread     = thread
        article.url        = url && url.strip
        article.subject    = subject && subject.strip        
        article.category   = nil
        article.user       = nil
        article.status     = open_status
        article.status_name= open_status.name
        article.created_at = Time.now
      end

      if article.replies != replies and article.status_id = closed_status.id     
        article.status = open_status  # re-open a closed issue, if reply count has changed
      end

      # set authors and response times
      if article.link_time.nil? or article.first_response.nil? or article.replies != replies
        user_response_time_map = {}
        
        answers_doc = open("#{url_prefix}#{question["question_answers_url"]}?&#{sof_key}").read
        answers = JSON.parse(Zlib::GzipReader.new(StringIO.new(answers_doc)).read)["answers"]
        
       answers.each do |answer|
         author = answer["owner"]["display_name"]
         response_time = Time.zone.at(answer["creation_date"])
         user_response_time_map[response_time] = author if response_time
       end 
        
        # set article submission time and author name
        article.link_time = Time.zone.at(question["creation_date"])
        article.author = question["owner"]["display_name"]
        
        # set first response time, last-user-responded and total number of users who answered
        response_times            = user_response_time_map.keys.sort!        
        article.first_response    ||= response_times.first
        article.last_responded_by = (replies > 0) ? user_response_time_map[response_times.last] : nil
        article.authors           = (user_response_time_map.values + [article.author]).uniq.size
      end
      
      article.replies = replies
       
      update_article(article, send_alerts)        
    end
    
  end # of stackoverflow
  
  
  #
  #
  #
  def update_article(article, send_alerts = false)
    # save the record
    begin
      article.save
      
      if send_alerts
        puts "[alerts] \t sending..."
        thread_url = article.domain + (article.url || "")
        
        AlertMailer.email_new_thread(thread_url, article.subject).deliver
        AlertMailer.sms_new_thread(thread_url, article.subject).deliver
      end
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
    end
  end
end # of scrape namespace
