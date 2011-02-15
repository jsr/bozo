Bozo::Application.routes.draw do
  devise_for :users, :controllers => {:registrations => "registrations"}
  
  root :to => "dashboard#index"
  
  resources :users
  resources :articles
  resources :categories
  
  resources :stats do 
    collection do
      get :open_close_by_users
      get :incoming_by_day
      get :closed_by_day
      get :incoming_by_hour
      get :close_time_by_day
    end
  end

  resource :dashboard, :controller => 'dashboard' do
    collection do
      get :byuser
    end
  end     

end # of routes
