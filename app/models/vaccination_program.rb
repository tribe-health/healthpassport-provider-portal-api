# frozen_string_literal: true

class VaccinationProgram < ApplicationRecord
  # t.string :vaccinator
  # t.string :brand
  # t.string :product
  # t.string :lot
  # t.string :dose
  # t.string :route
  # t.string :signature

  belongs_to :user
end
