# Using tabix with dbVar GVF and VCF FTP Files
# https://www.ncbi.nlm.nih.gov/dbvar/content/tools/tabix/

require "htslib"

url = "https://ftp.ncbi.nlm.nih.gov/pub/dbVar/data/Homo_sapiens/by_study/vcf/nstd102.GRCh38.variant_region.vcf.gz"

# Open online file
tb = HTS::Tabix.open(url)

# Query the first million bases using 0-based, half-open coordinates.
tb.query("1", 0, 1_000_000) do |r|
  puts r.join("\t")
end
