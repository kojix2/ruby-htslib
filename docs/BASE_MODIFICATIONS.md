# Base Modifications API

ruby-htslibのBase Modifications（塩基修飾）APIは、BAM/CRAM/SAMファイルからDNAやRNAの塩基修飾情報を抽出するための機能を提供します。この機能は、メチル化（methylation）やヒドロキシメチル化（hydroxymethylation）などの化学修飾を検出するために使用されます。

## 概要

Base Modifications APIは、SAM仕様のMM（Modified base）およびML（Modification likelihood）タグから情報を抽出します。htslibの`hts_base_mod`APIをラップし、Rubyらしいインターフェースを提供します。

## クラス構成

### `HTS::Bam::BaseMod`
メインクラス。BAMレコードから修飾塩基情報を抽出します。

### `HTS::Bam::BaseMod::Position`
特定の位置における修飾情報を表現します。

### `HTS::Bam::BaseMod::Modification`
個別の塩基修飾を表現します。

## 基本的な使い方

```ruby
require 'htslib'

# BAMファイルを開く
HTS::Bam.open('methylation_data.bam') do |bam|
  bam.each do |record|
    # レコードから修飾情報オブジェクトを取得
    base_mod = record.base_mod
    
    # MM/MLタグをパース
    n_types = base_mod.parse
    next if n_types <= 0  # 修飾情報がない場合はスキップ
    
    # 修飾タイプのリストを取得
    types = base_mod.modification_types
    puts "Modification types: #{types.join(', ')}"
    
    # 全ての修飾位置を走査
    base_mod.each_position do |pos|
      puts "Position #{pos.position} (strand #{pos.strand}):"
      
      pos.modifications.each do |mod|
        puts "  #{mod.canonical} -> #{mod.code}"
        puts "  Probability: #{mod.probability}" if mod.likelihood
      end
    end
  end
end
```

## 位置へのアクセス

### イテレータで全位置を走査

```ruby
base_mod.each_position do |pos|
  # pos は HTS::Bam::BaseMod::Position オブジェクト
  puts "Position: #{pos.position}"
  puts "Strand: #{pos.strand}"
  puts "Modifications: #{pos.modifications.length}"
end
```

### 特定の位置を直接クエリ

```ruby
# 位置10の修飾情報を取得
pos_info = base_mod.at_pos(10)

if pos_info
  puts "Modifications at position 10:"
  pos_info.modifications.each do |mod|
    puts "  #{mod}"
  end
end

# 配列スタイルのアクセスも可能
if base_mod[5]
  puts "Position 5 has modifications"
end
```

## 修飾タイプの確認

### 一般的な修飾の検出

```ruby
base_mod.each_position do |pos|
  # メチル化をチェック
  if pos.methylated?
    puts "Methylation at position #{pos.position}"
  end
  
  # ヒドロキシメチル化をチェック
  if pos.hydroxymethylated?
    puts "Hydroxymethylation at position #{pos.position}"
  end
end
```

### 記録されている修飾タイプの取得

```ruby
# このレコードに含まれる修飾タイプのリスト
types = base_mod.modification_types  # 例: ["m", "h"]

# 各タイプの詳細情報を取得
types.each do |type|
  info = base_mod.query_type(type)
  if info
    puts "Type '#{type}':"
    puts "  Canonical base: #{info[:canonical]}"
    puts "  Strand: #{info[:strand]}"
    puts "  Implicit: #{info[:implicit]}"
  end
end
```

## Modificationオブジェクトのプロパティ

```ruby
mod = HTS::Bam::BaseMod::Modification.new(
  code: "m",              # 修飾コード
  canonical: "C",         # 元の塩基
  modified: "5mC",        # 修飾後の塩基名（オプション）
  likelihood: 200         # 尤度 0-255（オプション）
)

mod.code         # => "m"
mod.canonical    # => "C"
mod.modified     # => "5mC"
mod.likelihood   # => 200
mod.probability  # => 0.784 (likelihood / 255.0)
mod.to_s         # => "C->m(0.784)"
mod.to_h         # => { code: "m", canonical: "C", ... }
```

## Positionオブジェクトのプロパティ

```ruby
pos.position      # クエリ配列内の位置（0-based）
pos.strand        # ストランド（0 or 1）
pos.modifications # Modificationオブジェクトの配列

pos.methylated?          # メチル化の有無
pos.hydroxymethylated?   # ヒドロキシメチル化の有無
pos.to_h                 # ハッシュに変換
pos.to_s                 # 文字列表現
```

## 一般的な修飾コード

| コード | 意味 | 元の塩基 |
|--------|------|----------|
| m | 5-メチルシトシン（5mC） | C |
| h | 5-ヒドロキシメチルシトシン（5hmC） | C |
| f | 5-ホルミルシトシン（5fC） | C |
| c | 5-カルボキシルシトシン（5caC） | C |
| g | 5-ヒドロキシメチル尿素 | T |
| a | 6-メチルアデニン（6mA） | A |

詳細は[SAM仕様書](https://samtools.github.io/hts-specs/SAMtags.pdf)を参照してください。

## 注意事項

### メモリ管理

`BaseMod`オブジェクトは内部でC構造体(`hts_base_mod_state`)を管理します。通常はガベージコレクタが自動的にメモリを解放しますが、明示的に解放したい場合は`close`メソッドを使用できます：

```ruby
base_mod = record.base_mod
base_mod.parse
# ... 処理 ...
base_mod.close  # 明示的に解放（通常は不要）
```

### スレッドセーフティ

`hts_base_mod_state`は状態を保持するため、スレッドセーフではありません。マルチスレッド環境では、各スレッドで独立した`BaseMod`インスタンスを使用してください。

### パフォーマンス

- `parse`は最初に一度だけ呼び出せば十分です
- 同じ位置に何度もアクセスする場合は、結果をキャッシュすることを検討してください
- 大量のレコードを処理する場合は、必要な情報だけを抽出するようにしましょう

## サンプルコード

完全なサンプルコードは`examples/base_mod.rb`を参照してください：

```bash
bundle exec ruby examples/base_mod.rb <bam_file_with_modifications>
```

## テスト

```bash
# Base Modificationsのテストのみ実行
bundle exec ruby test/base_mod_test.rb

# 全テストを実行
bundle exec rake test
```

## 参考資料

- [SAM Specification - Base Modifications](https://samtools.github.io/hts-specs/SAMtags.pdf)
- [htslib base modification API](https://github.com/samtools/htslib/blob/develop/htslib/sam.h)
- [Nanopore base modification detection](https://nanoporetech.com/nanopore-sequencing-data-analysis)
