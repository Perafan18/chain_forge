# frozen_string_literal: true

require 'dry-validation'

# Validator for block data
class BlockDataContract < Dry::Validation::Contract
  params do
    required(:data).filled(:string)
  end
end
