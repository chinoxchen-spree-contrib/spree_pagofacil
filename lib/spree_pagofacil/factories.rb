FactoryBot.define do
  # Define your Spree extensions Factories within this file to enable applications, and other extensions to use and override them.
  #
  # Example adding this to your spec_helper will load these Factories for use:
  # require 'spree_pagofacil/factories'

  factory :Pagofacil_payment_method, class: Spree::PaymentMethod::Pagofacil do
    name { 'Pagofacil' }
  end
end
