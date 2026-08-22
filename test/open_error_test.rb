# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"

class OpenErrorTest < Minitest::Test
  def test_hts_open_preserves_permission_denied
    Dir.mktmpdir do |dir|
      path = File.join(dir, "unreadable.hts")
      File.write(path, ">seq\nA\n")
      File.chmod(0, path)

      [HTS::Bam, HTS::Bcf, HTS::Tabix].each do |klass|
        assert_raises(Errno::EACCES) { klass.new(path) }
      end
    end
  end

  def test_faidx_open_preserves_permission_denied
    Dir.mktmpdir do |dir|
      path = File.join(dir, "unreadable.fa")
      FileUtils.cp(Fixtures["random.fa"], path)
      FileUtils.cp(Fixtures["random.fa.fai"], "#{path}.fai")
      File.chmod(0, path)

      assert_raises(Errno::EACCES) { HTS::Faidx.new(path, auto_build: false) }
    end
  end
end
