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

      begin
        [HTS::Bam, HTS::Bcf, HTS::Tabix].each do |klass|
          assert_raises(Errno::EACCES) { klass.new(path) }
        end
      ensure
        File.chmod(0o600, path)
      end
    end
  end

  def test_faidx_open_preserves_permission_denied
    Dir.mktmpdir do |dir|
      path = File.join(dir, "unreadable.fa")
      FileUtils.cp(Fixtures["random.fa"], path)
      FileUtils.cp(Fixtures["random.fa.fai"], "#{path}.fai")
      File.chmod(0, path)

      begin
        assert_raises(Errno::EACCES) { HTS::Faidx.new(path, auto_build: false) }
      ensure
        File.chmod(0o600, path)
      end
    end
  end
end
