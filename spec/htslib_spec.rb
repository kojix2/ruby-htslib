# frozen_string_literal: true

RSpec.describe HTS do
  it 'has a version number' do
    expect(HTS::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(HTS::FFI.hts_version).not_to be nil
  end
end
