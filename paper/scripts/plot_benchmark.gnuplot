if (!exists("datafile")) datafile = "paper/data/benchmark-throughput.tsv"
if (!exists("outfile")) outfile = "paper/figures/benchmark-throughput.png"

set terminal pngcairo size 1728,720 enhanced font "DejaVu Sans,18"
set output outfile
set datafile separator "\t"
set key top right horizontal samplen 1.5
set border 3 linewidth 1.2
set tics nomirror
set grid ytics linewidth 1 linecolor rgb "#d0d0d0" back
set ylabel "Throughput relative to C/HTSlib (%)"
set yrange [0:120]
set ytics 20
set bmargin 3.5
set xtics norotate font ",16"
set style data histograms
set style histogram clustered gap 1
set style fill pattern border linecolor rgb "black"
set boxwidth 0.82
set arrow from graph 0, first 100 to graph 1, first 100 nohead \
    dashtype 2 linewidth 1.4 linecolor rgb "black" front

plot datafile every ::1 using 2:xtic(1) title "hts.cr" \
        linecolor rgb "black" fillstyle pattern 3, \
     '' every ::1 using 3 title "ruby-htslib" \
        linecolor rgb "black" fillstyle pattern 7
