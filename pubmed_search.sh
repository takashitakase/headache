#!/usr/bin/env bash
# pubmed_search.sh
# 前日の頭痛（headache）関連論文をPubMed E-utilities APIで検索し、日本語で一覧表示するスクリプト
# 使い方: bash pubmed_search.sh [YYYY/MM/DD]
#   引数なし: 前日の論文を検索
#   引数あり: 指定日付の論文を検索（例: bash pubmed_search.sh 2026/05/04）

set -euo pipefail

# ----------------------------------------
# 設定
# ----------------------------------------
BASE_URL="https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
SEARCH_TERM="headache[Title/Abstract]"
MAX_RESULTS=100

# ----------------------------------------
# 日付の設定
# ----------------------------------------
if [ $# -ge 1 ]; then
  TARGET_DATE="$1"
else
  # 前日の日付を取得（macOS / Linux 両対応）
  TARGET_DATE=$(date -d '1 day ago' +%Y/%m/%d 2>/dev/null || date -v-1d +%Y/%m/%d)
fi

TODAY=$(date +%Y/%m/%d)
DISPLAY_DATE=$(echo "$TARGET_DATE" | sed 's|/|年|; s|/|月|')日

echo "========================================"
echo " 頭痛関連 PubMed 新着論文サマリー"
echo "========================================"
echo " 検索実行日  : $(echo "$TODAY" | sed 's|/|年|; s|/|月|')日"
echo " 対象日付    : ${DISPLAY_DATE}"
echo "========================================"
echo ""

# ----------------------------------------
# Step 1: esearch — PMIDリストを取得
# ----------------------------------------
SEARCH_URL="${BASE_URL}/esearch.fcgi?db=pubmed&term=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${SEARCH_TERM}'))")&datetype=pdat&mindate=${TARGET_DATE}&maxdate=${TARGET_DATE}&retmax=${MAX_RESULTS}&retmode=json"

SEARCH_RESULT=$(curl -sf "$SEARCH_URL" || { echo "エラー: PubMed検索APIへの接続に失敗しました。" >&2; exit 1; })

COUNT=$(echo "$SEARCH_RESULT" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['esearchresult']['count'])")
PMIDS=$(echo "$SEARCH_RESULT" | python3 -c "import sys, json; d=json.load(sys.stdin); print(','.join(d['esearchresult']['idlist']))")

echo "ヒット件数: ${COUNT} 件"
echo ""

if [ "$COUNT" = "0" ] || [ -z "$PMIDS" ]; then
  echo "昨日のヒットはありませんでした。"
  exit 0
fi

# ----------------------------------------
# Step 2: efetch — 詳細情報をXMLで取得
# ----------------------------------------
FETCH_URL="${BASE_URL}/efetch.fcgi?db=pubmed&id=${PMIDS}&rettype=abstract&retmode=xml"
XML_DATA=$(curl -sf "$FETCH_URL" || { echo "エラー: 論文詳細の取得に失敗しました。" >&2; exit 1; })

# ----------------------------------------
# Step 3: XMLをパースして一覧表示
# ----------------------------------------
echo "$XML_DATA" | python3 - <<'PYEOF'
import sys
import xml.etree.ElementTree as ET

xml_content = sys.stdin.read()
root = ET.fromstring(xml_content)

articles = root.findall('.//PubmedArticle')
print(f"論文一覧 ({len(articles)} 件)\n")
print("=" * 60)

for i, article in enumerate(articles, 1):
    # タイトル
    title_el = article.find('.//ArticleTitle')
    title = ''.join(title_el.itertext()) if title_el is not None else '（タイトル不明）'

    # 著者
    authors = article.findall('.//Author')
    author_names = []
    for a in authors:
        last = a.findtext('LastName', '')
        fore = a.findtext('ForeName', '')
        if last:
            author_names.append(f"{last} {fore}".strip())
    if len(author_names) > 1:
        author_str = f"{author_names[0]} et al."
    elif len(author_names) == 1:
        author_str = author_names[0]
    else:
        author_str = '（著者不明）'

    # 雑誌名
    journal = article.findtext('.//Journal/Title') or article.findtext('.//MedlineTA') or '（雑誌不明）'

    # 出版日
    pub_date = article.find('.//PubDate')
    if pub_date is not None:
        year  = pub_date.findtext('Year', '')
        month = pub_date.findtext('Month', '')
        day   = pub_date.findtext('Day', '')
        date_str = '-'.join(filter(None, [year, month, day]))
    else:
        date_str = '（日付不明）'

    # PMID
    pmid = article.findtext('.//PMID') or ''

    # DOI
    doi = ''
    for id_el in article.findall('.//ArticleId'):
        if id_el.get('IdType') == 'doi':
            doi = id_el.text or ''
            break

    # Abstract
    abstract_el = article.find('.//Abstract/AbstractText')
    if abstract_el is not None:
        abstract = ''.join(abstract_el.itertext())
    else:
        abstract = '（要旨なし）'
    abstract_short = abstract[:200] + '…' if len(abstract) > 200 else abstract

    print(f"\n### {i}. {title}")
    print(f"  著者    : {author_str}")
    print(f"  雑誌    : {journal}")
    print(f"  出版日  : {date_str}")
    print(f"  PMID    : https://pubmed.ncbi.nlm.nih.gov/{pmid}/")
    if doi:
        print(f"  DOI     : https://doi.org/{doi}")
    print(f"  要旨概要: {abstract_short}")
    print("-" * 60)

print("\n検索完了。")
PYEOF
