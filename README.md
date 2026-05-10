# headache — PubMed 頭痛論文 日次チェックツール

毎日 PubMed から頭痛（headache）関連の新着論文を自動収集し、Notion データベースへ保存するプロジェクトです。

## 概要

| 機能 | 内容 |
|------|------|
| 検索対象 | headache（頭痛全般）|
| 検索範囲 | 前日に公開された論文（PubMed 収載日ベース） |
| 取得情報 | タイトル・著者・雑誌名・出版日・DOI・PMID・要旨 |
| 自動保存先 | Notion データベース（1論文 = 1行） |
| 実行タイミング | 毎朝 6:00（JST）※ Claude Code ルーティンで自動実行 |

## ファイル構成

```
headache/
├── pubmed_search.sh   # PubMed検索スクリプト（ローカル実行用）
└── README.md
```

## 使い方

### ローカルで手動実行

```bash
# 前日の論文を検索（引数なし）
bash pubmed_search.sh

# 特定日付の論文を検索
bash pubmed_search.sh 2026/05/04
```

### 必要環境

- `curl`
- `python3`（標準ライブラリのみ使用）

## 自動実行（Claude Code ルーティン）

毎朝 6:00 JST に Claude Code のリモートルーティンが起動し、
PubMed 検索 → 日本語要約生成 → Notion データベース保存 を自動実行します。

Notion データベースの列構成:

| 列名 | 型 | 内容 |
|------|----|------|
| タイトル（英語） | title | 論文タイトル原文 |
| 著者 | text | 第一著者名 |
| 雑誌名 | text | ジャーナル名 |
| 出版日 | date | 出版年月日 |
| DOI | url | DOI リンク |
| PMID | text | PubMed ID |
| 要旨（日本語） | text | 日本語要約（2〜4文） |
| 検索日 | date | 検索実行日 |

## 参考

- [PubMed E-utilities API](https://www.ncbi.nlm.nih.gov/books/NBK25497/)
- [Claude Code ルーティン管理](https://claude.ai/code/routines)
