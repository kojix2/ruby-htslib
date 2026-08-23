// C/HTSlib baseline benchmark for the hts.cr / ruby-htslib performance table.
// Build: gcc -O2 -o bench_c bench_c.c $(pkg-config --cflags --libs htslib)
//
// Workloads (matching the paper's performance table):
//   1. Sequential BAM record scan (no field conversion)
//   2. BAM scan with flag and coordinate access
//   3. Sequential BCF record scan (site fields only)
//   4. FORMAT/GT integer traversal (raw genotype ints, no strings)
//   5. FORMAT/GT string conversion (allocating convenience path)
//   6. FORMAT/DP and FORMAT/AD traversal (scalar and vector access)
//   7. Indexed region query (first vs repeated)
//   8. Pileup base counting (fixed quality thresholds)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <htslib/sam.h>
#include <htslib/vcf.h>

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

static void report(const char *label, double seconds, long n) {
    printf("%-40s %10.4fs  %14.0f records/s (n=%ld)\n", label, seconds, n / seconds, n);
    fflush(stdout);
}

static long bench_bam_scan(const char *path) {
    samFile *in = sam_open(path, "r");
    if (!in) { fprintf(stderr, "open failed: %s\n", path); exit(1); }
    sam_hdr_t *hdr = sam_hdr_read(in);
    bam1_t *b = bam_init1();
    long n = 0;
    double t0 = now_sec();
    while (sam_read1(in, hdr, b) >= 0) n++;
    double t1 = now_sec();
    report("Sequential BAM record scan", t1 - t0, n);
    bam_destroy1(b);
    sam_hdr_destroy(hdr);
    sam_close(in);
    return n;
}

static long bench_bam_flag_coord(const char *path) {
    samFile *in = sam_open(path, "r");
    sam_hdr_t *hdr = sam_hdr_read(in);
    bam1_t *b = bam_init1();
    long n = 0;
    volatile long acc = 0;
    double t0 = now_sec();
    while (sam_read1(in, hdr, b) >= 0) {
        acc += b->core.flag;
        acc += b->core.tid;
        acc += b->core.pos;
        n++;
    }
    double t1 = now_sec();
    report("BAM scan w/ flag+coord access", t1 - t0, n);
    bam_destroy1(b);
    sam_hdr_destroy(hdr);
    sam_close(in);
    return n;
}

static long bench_bcf_scan(const char *path) {
    htsFile *in = bcf_open(path, "r");
    bcf_hdr_t *hdr = bcf_hdr_read(in);
    bcf1_t *rec = bcf_init();
    long n = 0;
    double t0 = now_sec();
    while (bcf_read(in, hdr, rec) == 0) {
        bcf_unpack(rec, BCF_UN_STR); // site fields only (chrom/pos/id/ref/alt/qual/filter)
        n++;
    }
    double t1 = now_sec();
    report("Sequential BCF record scan", t1 - t0, n);
    bcf_destroy(rec);
    bcf_hdr_destroy(hdr);
    bcf_close(in);
    return n;
}

static long bench_gt_int(const char *path) {
    htsFile *in = bcf_open(path, "r");
    bcf_hdr_t *hdr = bcf_hdr_read(in);
    bcf1_t *rec = bcf_init();
    int32_t *gt_arr = NULL;
    int ngt_arr = 0;
    long n = 0;
    volatile long acc = 0;
    double t0 = now_sec();
    while (bcf_read(in, hdr, rec) == 0) {
        bcf_unpack(rec, BCF_UN_ALL);
        int ngt = bcf_get_genotypes(hdr, rec, &gt_arr, &ngt_arr);
        for (int i = 0; i < ngt; i++) acc += gt_arr[i];
        n++;
    }
    double t1 = now_sec();
    report("FORMAT/GT integer traversal", t1 - t0, n);
    free(gt_arr);
    bcf_destroy(rec);
    bcf_hdr_destroy(hdr);
    bcf_close(in);
    return n;
}

static long bench_gt_string(const char *path) {
    htsFile *in = bcf_open(path, "r");
    bcf_hdr_t *hdr = bcf_hdr_read(in);
    bcf1_t *rec = bcf_init();
    int32_t *gt_arr = NULL;
    int ngt_arr = 0;
    int n_samples = bcf_hdr_nsamples(hdr);
    long n = 0;
    double t0 = now_sec();
    while (bcf_read(in, hdr, rec) == 0) {
        bcf_unpack(rec, BCF_UN_ALL);
        int ngt = bcf_get_genotypes(hdr, rec, &gt_arr, &ngt_arr);
        int ploidy = n_samples > 0 ? ngt / n_samples : 0;
        for (int s = 0; s < n_samples; s++) {
            char buf[32];
            int off = 0;
            for (int p = 0; p < ploidy; p++) {
                int32_t allele = gt_arr[s * ploidy + p];
                int allele_idx = bcf_gt_is_missing(allele) ? -1 : bcf_gt_allele(allele);
                off += snprintf(buf + off, sizeof(buf) - off, "%s%d",
                                 p ? (bcf_gt_is_phased(allele) ? "|" : "/") : "", allele_idx);
            }
            char *s_alloc = strdup(buf); // force an allocation, mirroring string-materializing APIs
            free(s_alloc);
        }
        n++;
    }
    double t1 = now_sec();
    report("FORMAT/GT string conversion", t1 - t0, n);
    free(gt_arr);
    bcf_destroy(rec);
    bcf_hdr_destroy(hdr);
    bcf_close(in);
    return n;
}

static long bench_dp_ad(const char *path) {
    htsFile *in = bcf_open(path, "r");
    bcf_hdr_t *hdr = bcf_hdr_read(in);
    bcf1_t *rec = bcf_init();
    int32_t *dp_arr = NULL, *ad_arr = NULL;
    int ndp_arr = 0, nad_arr = 0;
    long n = 0;
    volatile long acc = 0;
    double t0 = now_sec();
    while (bcf_read(in, hdr, rec) == 0) {
        bcf_unpack(rec, BCF_UN_ALL);
        int ndp = bcf_get_format_int32(hdr, rec, "DP", &dp_arr, &ndp_arr);
        int nad = bcf_get_format_int32(hdr, rec, "AD", &ad_arr, &nad_arr);
        for (int i = 0; i < ndp; i++) acc += dp_arr[i];
        for (int i = 0; i < nad; i++) acc += ad_arr[i];
        n++;
    }
    double t1 = now_sec();
    report("FORMAT/DP+AD traversal", t1 - t0, n);
    free(dp_arr);
    free(ad_arr);
    bcf_destroy(rec);
    bcf_hdr_destroy(hdr);
    bcf_close(in);
    return n;
}

static void bench_region_query(const char *path, const char *region) {
    samFile *in = sam_open(path, "r");
    sam_hdr_t *hdr = sam_hdr_read(in);
    hts_idx_t *idx = sam_index_load(in, path);
    if (!idx) { fprintf(stderr, "index load failed\n"); exit(1); }
    bam1_t *b = bam_init1();

    // First query (cold)
    double t0 = now_sec();
    hts_itr_t *itr = sam_itr_querys(idx, hdr, region);
    long n = 0;
    while (sam_itr_next(in, itr, b) >= 0) n++;
    hts_itr_destroy(itr);
    double t1 = now_sec();
    report("Indexed region query (first)", t1 - t0, n);

    // Repeated queries (warm index, index already loaded)
    int repeats = 20;
    double t2 = now_sec();
    long n2 = 0;
    for (int r = 0; r < repeats; r++) {
        hts_itr_t *itr2 = sam_itr_querys(idx, hdr, region);
        while (sam_itr_next(in, itr2, b) >= 0) n2++;
        hts_itr_destroy(itr2);
    }
    double t3 = now_sec();
    report("Indexed region query (repeated x20, per-call avg)", (t3 - t2) / repeats, n2 / repeats);

    bam_destroy1(b);
    hts_idx_destroy(idx);
    sam_hdr_destroy(hdr);
    sam_close(in);
}

// Reader context + callback used to drive bam_plp_auto()/bam_plp_next() on demand,
// which is the idiomatic htslib usage (mirrors samtools' own bam2depth.c). Pushing
// every read up-front before draining the pileup buffer causes pathological,
// super-linear behavior because the buffer cannot evict finished reads early.
typedef struct {
    samFile *in;
    hts_itr_t *itr;
} plp_reader_t;

static int plp_read_cb(void *data, bam1_t *b) {
    plp_reader_t *r = (plp_reader_t *)data;
    return sam_itr_next(r->in, r->itr, b);
}

static void bench_pileup_base_counts(const char *path, const char *region) {
    samFile *in = sam_open(path, "r");
    sam_hdr_t *hdr = sam_hdr_read(in);
    hts_idx_t *idx = sam_index_load(in, path);
    if (!idx) { fprintf(stderr, "index load failed\n"); exit(1); }

    int min_base_q = 13;
    int min_map_q = 0;

    double t0 = now_sec();
    plp_reader_t reader;
    reader.in = in;
    reader.itr = sam_itr_querys(idx, hdr, region);

    bam_plp_t plp = bam_plp_init(plp_read_cb, &reader);
    long columns = 0;
    long total_bases = 0;

    int tid, pos, n_plp;
    const bam_pileup1_t *pileup;
    while ((pileup = bam_plp_auto(plp, &tid, &pos, &n_plp)) != 0) {
        columns++;
        for (int i = 0; i < n_plp; i++) {
            const bam_pileup1_t *p = pileup + i;
            if (p->is_del || p->is_refskip) continue;
            uint8_t qual = bam_get_qual(p->b)[p->qpos];
            if (qual < min_base_q) continue;
            if (p->b->core.qual < min_map_q) continue;
            total_bases++;
        }
    }
    double t1 = now_sec();
    report("Pileup base counting", t1 - t0, columns);
    printf("%-40s columns=%ld bases_counted=%ld\n", "  (pileup detail)", columns, total_bases);

    bam_plp_destroy(plp);
    hts_itr_destroy(reader.itr);
    hts_idx_destroy(idx);
    sam_hdr_destroy(hdr);
    sam_close(in);
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s <bench.bam> <bench.bcf> [region]\n", argv[0]);
        return 1;
    }
    const char *bam_path = argv[1];
    const char *bcf_path = argv[2];
    const char *region = argc > 3 ? argv[3] : "chr1:500000-600000";

    printf("HTSlib version: %s\n", hts_version());
    printf("BAM: %s\nBCF: %s\nRegion: %s\n\n", bam_path, bcf_path, region);

    bench_bam_scan(bam_path);
    bench_bam_flag_coord(bam_path);
    bench_bcf_scan(bcf_path);
    bench_gt_int(bcf_path);
    bench_gt_string(bcf_path);
    bench_dp_ad(bcf_path);
    bench_region_query(bam_path, region);
    bench_pileup_base_counts(bam_path, region);

    return 0;
}
