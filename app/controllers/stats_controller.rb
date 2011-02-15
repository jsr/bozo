#
#
class StatsController < ApplicationController

  before_filter :authenticate_user!
  
  #
  #
  #
  def index

  end

  #
  #
  #
  def incoming_by_day
    map_function    = %( function() {
        var date = this.link_time;
        var y = date.getFullYear();
        var m = date.getMonth()+1;
        var d = date.getDate(); 
        emit( new Date(y + "/" + m + "/" + d) , 1); 
    })

    reduce_function = %( function(key, values) { 
      var total = 0; 
      for ( var i=0; i < values.length; i++ ) { 
        total += values[i]; 
      } 
      return total; 
    })

    @current_date   = Time.zone.today
    start_of_month  = @current_date.advance(:months => -11).beginning_of_month.beginning_of_day
    end_of_month    = @current_date.end_of_month.end_of_day
    
    MongoMapper.database['mr_incoming_by_day'].drop() # remove temp collection for map_reduce
    x = Article.collection.map_reduce(map_function, reduce_function,
                                      { :out => 'mr_incoming_by_day',
                                        :query => {:link_time => {"$gte" => start_of_month.utc, "$lte" => end_of_month.utc}}}).find().to_a
    
    set_monthly_stats(x)
  end


  #
  #
  #
  def closed_by_day
    closed_status   = Status.find_by_name('Closed')
    
    map_function    = %( function() {
        var date = this.link_time;
        var y = date.getFullYear();
        var m = date.getMonth()+1;
        var d = date.getDate(); 
        emit( new Date(y + "/" + m + "/" + d) , 1); 
    })

    reduce_function = %( function(key, values) { 
      var total = 0; 
      for ( var i=0; i < values.length; i++ ) { 
        total += values[i]; 
      } 
      return total; 
    })

    @current_date   = Time.zone.today
    start_of_month  = @current_date.advance(:months => -11).beginning_of_month.beginning_of_day
    end_of_month    = @current_date.end_of_month.end_of_day
    
    MongoMapper.database['mr_closed_by_day'].drop() # remove temp collection for map_reduce
    x = Article.collection.map_reduce(map_function, reduce_function,
                                      { :out => 'mr_closed_by_day',
                                        :query => { :link_time => {"$gte" => start_of_month.utc, "$lte" => end_of_month.utc},
                                                    :status_id  => closed_status.id}}).find().to_a

    set_monthly_stats(x)
  end

  #
  #
  #
  def incoming_by_hour
    @current_date   = Time.zone.today
    start_date      = (@current_date - @current_date.wday).beginning_of_day
    end_date        = (@current_date - @current_date.wday + 6).end_of_day
    articles        = Article.where({:link_time => {"$gte" => start_date.utc, "$lte" => end_date.utc}}).all

    @day_stats = []

    articles_group = articles.group_by { |x| x.link_time.to_date }
    articles_group.keys.sort.each do |k|
      values = articles_group[k]
      time_map = {}
      0.upto(23).each { |i| time_map[i] = 0 }

      values.each do |value| 
        time_map[value.link_time.hour] += 1
      end
      
      @day_stats << {:label => l(k.to_date, :format => :wday_and_short_date), :stats => time_map}      
    end
    
    # Add weekly average
    @avg_stats = { :label => "Weekly Average" }
    time_map = {}

    # collect average for each hour
    0.upto(23).each do |i|
      incoming_total = 0.0
      
      # go over each day (same time)
      @day_stats.each do |stats_map| 
        incoming_total += stats_map[:stats][i]
      end
      
      time_map[i] = (incoming_total / @day_stats.size)  
    end
    
    @avg_stats[:stats] = time_map
    @day_stats << @avg_stats
  end
  
  
  #
  #
  #
  def close_time_by_day
    closed_status   = Status.find_by_name('Closed')

    map_function    = %( function() {
        var date = this.link_time;
        var y = date.getFullYear();
        var m = date.getMonth()+1;
        var d = date.getDate(); 
        emit( new Date(y + "/" + m + "/" + d), (this.time_closed - date) / 3600000); 
    })

    reduce_function = %( function(key, values) { 
      var total = 0; 
      for ( var i=0; i < values.length; i++ ) { 
        total += values[i]; 
      } 
      return (total / values.length); 
    })

    @current_date   = Time.zone.today
    start_of_month  = @current_date.advance(:months => -11).beginning_of_month.beginning_of_day
    end_of_month    = @current_date.end_of_month.end_of_day
    
    MongoMapper.database['mr_close_time_by_day'].drop() # remove temp collection for map_reduce
    x = Article.collection.map_reduce(map_function, reduce_function,
                                      { :out => 'mr_close_time_by_day',
                                        :query => { :link_time => {"$gte" => start_of_month.utc, "$lte" => end_of_month.utc},
                                                    :status_id  => closed_status.id}}).find().to_a

    set_monthly_stats(x)
  end
  
  
  #
  #
  #
  def open_close_by_users
    open_status   = Status.find_by_name('Open')
    closed_status = Status.find_by_name('Closed')
    
    @current_date   = Time.zone.today
    @start_of_month  = (@current_date -30).beginning_of_day
    @end_of_month    = @current_date.end_of_day

    # get all open & assigned articles + all closed articles that were closed in last 30 days 
    x = Article.where( "$or" => [{ "status_id" => open_status.id, "user_id" => {"$ne" => nil} }, 
                                 { "status_id" => closed_status.id, "time_closed" => {"$gte" => @start_of_month.utc} }]).all
    
    # map the articles open/close counts to respective user 
    @user_stat_map = {}
    x.each do |article|
      user_nickname = article.user_nickname
      if user_nickname.blank?
        next
      end
      user_stat = (@user_stat_map[user_nickname] ||= {})
      
      (@start_of_month.to_date..@end_of_month.to_date).each do |date|
        date_stat = (user_stat[date] ||= {})
        if (date <= ((article.time_closed && article.time_closed.to_date) || @current_date)) and 
           (date >= ((article.time_assigned && article.time_assigned.to_date) || @current_date - 1))
          date_stat[:open] = (date_stat[:open] ||= 0) + 1
        else
          date_stat[:open] ||= 0
        end
      end
      
      if article.time_closed
        date_stat = user_stat[article.time_closed.to_date] ||= {}
        date_stat[:closed] = (date_stat[:closed] ||= 0) + 1
      end
    end # article loop
    
  end # of method 'open_close_by_users' 
  
  
  #\\\\\\\\\\\\\\\\\\\
  private
  
  #
  # expects results in the format [ {'_id' => some_time, "value" => an_int}, {...} , {...}, ...] 
  #
  def set_monthly_stats(results)
    @monthly_stats = {}
    curr_month = nil
    data_x = []
    data_y = []
    
    results.each do |xs|
      date = xs["_id"].to_date
      label = l(date, :format => :long_mon_and_year)
      
      if date.month != curr_month
        curr_month = date.month
        data_x = []
        data_y = []
        @monthly_stats[date] = {:label => label, :stats => [data_x, data_y] }
      end
      
      data_x << xs["_id"].day
      data_y << xs["value"].to_i
    end
  end

end # of class
