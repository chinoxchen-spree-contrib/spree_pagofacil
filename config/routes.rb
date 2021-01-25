Spree::Core::Engine.routes.draw do
  post '/pagofacil', to: "pagofacil#pay", as: :pagofacil
  post '/pagofacil/success/:payment', to: "pagofacil#success", as: :pagofacil_success
  get '/pagofacil/cancel/:payment', to: "pagofacil#cancel", as: :pagofacil_cancel
  post '/pagofacil/notify', to: 'pagofacil#notify'
end
