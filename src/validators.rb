# frozen_string_literal: true

require 'dry-validation'

# Validator for block data
class BlockDataContract < Dry::Validation::Contract
  params do
    required(:data).filled(:string)
    optional(:difficulty).maybe(:integer)
  end

  rule(:difficulty) do
    if value
      key.failure('must be a positive integer') if value <= 0
      key.failure('must be between 1 and 10') if value > 10
    end
  end
end
