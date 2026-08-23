---
title: "`ruby-htslib` と `hts.cr`：Ruby および Crystal 向け HTSlib インターフェース"
lang: ja
tags:
  - bioinformatics
  - genomics
  - HTSlib
  - sequencing
  - Crystal
  - Ruby
authors:
  - name: kojix2
    corresponding: true
date: 2026年8月23日
bibliography: ruby-htslib.bib
documentclass: article
fontsize: 10pt
papersize: a4
header-includes:
  - \usepackage[a4paper,margin=24mm]{geometry}
  - \usepackage{luatexja-fontspec}
  - \setmainjfont{Noto Serif CJK JP}
---

# 概要

`HTSlib` は、ゲノムデータの読み書きに用いられる C ライブラリであり、
`samtools` および `bcftools` の基盤をなす
[@Bonfield2021HTSlib; @Danecek2021SAMtools]。`hts.cr` と `ruby-htslib` は、
HTSlib を Crystal および Ruby から利用できるようにする。両ライブラリは、
SAM/BAM/CRAM、VCF/BCF、インデックス付き参照配列（Faidx）、Tabix ファイル、
pileup をサポートする。

`ruby-htslib` は、システムの HTSlib に
直接リンクする Ruby のネイティブ C 拡張を使用する。一方、`hts.cr` は Crystal の
FFI を介して HTSlib を呼び出す。これらのライブラリにより、Ruby または Crystal を
用いる研究者や開発者は、外部コマンドを介さずにゲノムデータをプログラム内で処理できる。

# 必要性

ゲノムデータに対する多くの定型処理には、専用のコマンドラインツールが提供されている。
しかし、研究上の問いに応じて複数のフィールドを組み合わせて選別・集計したり、レコードを
探索的に調べたり、結果を独自のデータ構造に格納して別のライブラリと連携させたりする場合には、
既存ツールのオプションだけでは処理を表現できず、独自のスクリプトやプログラムが必要となる
ことがある。
HTSlib は、ファイル形式の解釈、圧縮、インデックスを用いた検索などを C API として提供する。
これらを高水準言語から扱うには、関数を呼び出すだけでなく、HTSlib のファイル、ヘッダー、
レコードとその生存期間を、各言語のデータモデルに対応づける必要がある。

Python、Nim、Rust、C++ には、`pysam`、`cyvcf2`、`hts-nim`、
`rust-htslib`、`vcfpp` など、成熟した HTSlib インターフェースが存在する
[@pysam; @Pedersen2017cyvcf2; @Pedersen2018htsnim; @rust_htslib;
@Li2024vcfpp]。ただし、これらは各言語向けのインターフェースであり、Ruby または Crystal の
プログラムから直接利用することはできない。Ruby では、BioRuby のプラグインである
`bio-samtools` が、SAMtools を利用したアラインメント処理、pileup、変異解析、可視化の
高水準インターフェースを提供してきた [@Goto2010BioRuby;
@RamirezGonzalez2012BioSamtools; @Etherington2015BioSamtools2]。これに対し、
`ruby-htslib` は独立した HTSlib に直接接続し、アラインメントとバリアントのファイル、
ヘッダー、レコードを、Ruby で解析プログラムを構築するための構成要素として提供する。
`hts.cr` は、同じ HTSlib の機能を Crystal の静的型とネイティブコンパイルから利用し、
処理の中心部分を別の言語で実装することなく、ストリーミング型のバイオインフォマティクス
ツールを記述できるようにする。両ライブラリは、HTSlib の機能をそれぞれの言語に適した形で
組み合わせられるようにする。

# ソフトウェア設計

両ライブラリは、HTSlib のファイル、ヘッダー、レコードを共通のレコード指向モデルで表す。
このモデルは、ネイティブリソースの生存期間を管理し、走査中だけ借用する値と走査後も保持する
値を区別する。`Bam` は SAM/BAM/CRAM、`Bcf` は VCF/BCF のファイルを表し、それぞれが対応する
`Header` を保持する。ファイルオブジェクトの `each` は `Record` を一件ずつ返し、走査中は
同じオブジェクトとネイティブバッファを使い回す。この方法はファイル全体をメモリに展開せず、
割り当てを抑えて処理できる一方、走査後もレコードを保持する場合には複製する必要がある。
レコードのフィールドは Ruby または Crystal のメソッドから参照・更新でき、アラインメントの
補助タグとバリアントの INFO・FORMAT フィールドは型付きの値として扱われる。領域検索と
書き込みにも同じファイル、ヘッダー、レコードのオブジェクトを用いる。

この共通モデルにすべての操作を当てはめるのではなく、アクセスの単位が異なる機能には専用の
オブジェクトを用いる。インデックス付き FASTA は参照配列の一部を取得する `Faidx`、Tabix で
索引付けされたテキストは指定領域に重なる行を返す `Tabix` として表す。pileup は独立した
ファイル形式ではなく、`Bam` から得られる位置単位のビューとして、参照配列上の位置とそこに
重なるアラインメントの集合を列挙する。各ファイルオブジェクトはブロック付きで開くことができ、
ブロックの処理後にファイルを閉じ、ネイティブリソースを解放する。

このオブジェクトモデルを共有する一方、借用した値の公開方法と、値を保持するための経路には
各言語の利用形態を反映する。`ruby-htslib` の C 拡張は、HTSlib のポインターを型付きの
Ruby オブジェクトに格納し、
ガベージコレクションの際に対応する解放関数を呼び出す。走査ではネイティブのレコード
バッファを使い回し、走査後も保持するレコードやフィールドは独立した Ruby オブジェクトに
コピーする。BCF の FORMAT フィールドには、コピーせずに再利用バッファを参照する借用
view も用意する。したがって、値を Ruby の配列や文字列として保持する経路と、借用した値を
走査中に処理して割り当てを抑える経路を、用途に応じて選択できる。

`hts.cr` は、HTSlib のポインターを Crystal の静的型付きオブジェクトで包み、借用と所有の
区別を型とブロックの有効範囲に反映する。ネイティブバッファは、ブロック内だけ有効な `Slice`
や借用 view として参照でき、フィールドをプリミティブ値の iterator で処理すれば、中間的な
配列や文字列を生成しない。走査後も必要な値だけをコピーすることで、ヒープへの割り当てと
ガベージコレクタの負荷を抑える。この構成は、Crystal のネイティブコンパイルを利用した
ストリーミングツールにおいて、HTSlib のデータを効率よく逐次処理できるようにする。

# 性能評価

各ライブラリの実行時オーバーヘッドを調べるため、同じ処理を C、`hts.cr`、
`ruby-htslib` で実装し、スループットを比較した。三つの実装はいずれも同じ HTSlib
（1.22.1-51-gcd2a6f61）を使用し、Ubuntu 26.04 LTS 上でシングルスレッドで実行した。
C の基準実装は gcc 15.2.0（`-O2`）、`hts.cr`
0.4.0 は Crystal 1.21.0（LLVM 20.1.8、`--release`）、`ruby-htslib` 0.6.0 は
Ruby 4.0.6 でビルドした。したがって、この比較は、HTSlib 自体の違いではなく、
言語境界と各 API のデータ表現に伴うコストを反映する。

評価には、2 Mbp の参照配列に対する 100 bp の single-end リード 300,000 件を含む
BAM（平均深度約 15×）と、GT、DP、AD、GL の FORMAT フィールドを持つ 20 サンプル、
50,000 サイトの BCF を合成して用いた。BAM は座標順にソートし、両ファイルにインデックスを
作成した。領域検索と pileup の対象は、14,902 件のリードが重なる 100 kb の区間
（`chr1:500,000-600,000`）とした。pileup では base quality の下限を 13 とし、
mapping quality によるフィルタリングは行わなかった。各ワークロードを 5 回実行し、表には
スループットの中央値を示す。初回後は入力がページキャッシュに収まった。スクリプトは
`benchmark` ディレクトリに収録している。

![C/HTSlib 実装を基準としたスループットの中央値。領域検索には20回反復時の1回あたりの平均値を用いた。](figures/benchmark-throughput.png){width=100%}

\newpage

| ワークロード | C/HTSlib | `hts.cr` | `ruby-htslib` |
| --- | ---: | ---: | ---: |
| BAM レコードの逐次走査 | 2,938,000 records/s | 3,009,000 records/s | 1,689,000 records/s |
| flag と座標を参照する BAM 走査 | 2,949,000 records/s | 2,895,000 records/s | 1,326,000 records/s |
| BCF レコードの逐次走査 | 1,624,000 records/s | 1,738,000 records/s | 1,080,000 records/s |
| FORMAT/GT の整数走査 | 1,425,000 records/s | 1,345,000 records/s | 54,000 records/s |
| FORMAT/GT の文字列変換 | 438,000 records/s | 386,000 records/s | 29,000 records/s |
| FORMAT/DP・AD の走査 | 1,357,000 records/s | 827,000 records/s | 43,000 records/s |
| 領域検索（初回／20 回反復時の平均） | 2,622,000 / 2,674,000 records/s | 2,634,000 / 2,694,000 records/s | 1,725,000 / 1,761,000 records/s |
| pileup の塩基カウント | 6,792,000 columns/s | 4,846,000 columns/s | 140,000 columns/s |

レコードの逐次走査、整数値の FORMAT フィールドへのアクセス、領域検索では、`hts.cr` の
スループットは C の 94〜107% であった。サンプルごとの GT を文字列に変換する処理では
C の 88%、FORMAT/DP・AD の走査では 61%、pileup の塩基カウントでは 71% であった。
ネイティブバッファを直接処理できる経路では C に近い性能が得られ、文字列の生成や
高水準の view を介した値の走査には追加のコストが伴うことを示している。

`ruby-htslib` は、逐次走査と領域検索で C の 45〜67% のスループットを示した。FORMAT
フィールドや pileup の処理では差が大きく、C に対するスループットは 2〜7% であった。
FORMAT/GT の整数走査と FORMAT/DP・AD の走査には、割り当てを抑える iterator または
借用 view を用いたが、Ruby の値への変換とブロック呼び出しはレコード内の値ごとに発生する。
GT の文字列変換と pileup では、所有型の値を返す `genotype_strings` と
`each_base_counts` を用いており、コピーとオブジェクト生成のコストも含まれる。なお、
三つの実装はすべて同じレコード数を処理し、pileup で数えた塩基の総数も 1,017,916 で
一致した。

この評価は、各言語の優劣を一般化するものではなく、本稿で提供する API の代表的な実行経路を
比較したものである。結果は単一の実行環境と合成データセットに基づくため、実データを用いた
アプリケーション全体の実行時間や、大規模ファイルに対する性能を予測するものではない。

# 研究への影響

BioCrystal では、`hts.cr` は、式に基づいて BAM/CRAM をフィルタリングする
コマンドラインツール `bam-filter` と、libui-ng を用いた BAM viewer `bamboo` に
利用されている [@bam_filter; @bamboo]。

# AI 利用に関する開示

本稿の作成に Codex を使用した。

# 謝辞

`ruby-htslib` の開発は、Ruby Association Grant 2020 から一部支援を受けた
[@ruby_association_grant]。著者は、HTSlib、SAMtools、BCFtools、Ruby、Crystal の
開発者と、関連するバイオインフォマティクスコミュニティに感謝する。資金提供者は
ソフトウェアの設計と投稿の決定に関与していない。著者は利益相反がないことを宣言する。

# 参考文献
