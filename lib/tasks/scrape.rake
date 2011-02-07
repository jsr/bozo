namespace :scrape do
  desc "Scrape the mongodb_user page for new threads"
  task :mongodb_user => :environment do
    require 'open-uri'

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
          article.thread     = thread
          article.url        = url && url.strip
          article.subject    = subject && subject.strip
          article.replies    = replies
          article.authors    = num_authors
          article.category   = nil
          article.user       = nil
          article.status     = open_status
          article.status_name= open_status.name
          article.created_at = Time.now
        end

        if article.replies != replies and article.status_id = closed_status.id     
          article.status = open_status  # re-open a closed issue, if reply count has changed
        end         
        
        article.replies   = replies
        article.authors   = num_authors
        
        # set response times
        if article.link_time.nil? or article.first_response.nil? 
          user_response_time_map = {}
          response_doc = Nokogiri::HTML(open("http://groups.google.com" + (url || "")).read)
          
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
          
          response_times = user_response_time_map.keys.sort!
          article.link_time ||= response_times[0]
          article.first_response ||= response_times[1]
          
          article.author = (user_response_time_map[response_times[0]] || "<no user found?>").strip
        end
        
        # save the record
        begin
          article.save
        rescue Exception => e
          puts e.message
          puts e.backtrace.inspect
        end
          
        if send_alerts
          puts "[alerts] \t sending..."
  
          begin
            thread_url = "http://groups.google.com" + (article.url || "")
            AlertMailer.email_new_thread(thread_url, article.subject).deliver
            AlertMailer.sms_new_thread(thread_url, article.subject).deliver
          rescue Exception => e
            puts "Alert : "
            puts e.message
          end
        end
      end
    end

  end # of mongodb_user task
end # of scrape task
