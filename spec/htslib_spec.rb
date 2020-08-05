# frozen_string_literal: true

RSpec.describe HTSlib do
  it 'has a version number' do
    expect(HTSlib::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(HTSlib::Native.hts_version).not_to be nil
  end
end
