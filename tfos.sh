#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
DOWNLOAD_DIR="$SCRIPT_DIR/downloads"
SNAPSHOT="$DOWNLOAD_DIR/All-SET-MTFS.xlsx"
REPORT_XLSX="$DOWNLOAD_DIR/All-SET-MTFS_output.xlsx"
TMP_DIR=""

cleanup() {
  [[ -z "$TMP_DIR" || ! -d "$TMP_DIR" ]] || rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ ไม่พบไฟล์ .env; คัดลอก .env.example และกำหนด SET_DATA_URL" >&2
  exit 1
fi
if [[ $# -ne 1 ]]; then
  echo "Usage: ./update.sh [UPDATE/<AKA>-<AKA>-...]" >&2
  echo "       ./candidate.sh [CANDIDATE]" >&2
  exit 2
fi
COMMAND="$1"
SELECTED=""
case "$COMMAND" in
  UPDATE|CANDIDATE) ;;
  UPDATE/*)
    SELECTED="${COMMAND#UPDATE/}"
    AKA_PATTERN='^[A-Za-z0-9][A-Za-z0-9._&-]*(-[A-Za-z0-9][A-Za-z0-9._&-]*)*$'
    if [[ ! "$SELECTED" =~ $AKA_PATTERN ]]; then
      echo "❌ รูปแบบรายการ AKA ไม่ถูกต้อง" >&2
      exit 2
    fi
    COMMAND=UPDATE
    ;;
  *)
    echo "❌ คำสั่งไม่ถูกต้อง" >&2
    exit 2
    ;;
esac

SET_DATA_URL=""
SET_DATA_SHEET="All-SET-MTFS"
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    SET_DATA_URL=*) SET_DATA_URL="${line#SET_DATA_URL=}" ;;
    SET_DATA_SHEET=*) SET_DATA_SHEET="${line#SET_DATA_SHEET=}" ;;
  esac
done < "$ENV_FILE"
SET_DATA_URL="${SET_DATA_URL%$'\r'}"
SET_DATA_SHEET="${SET_DATA_SHEET%$'\r'}"
SET_DATA_URL="${SET_DATA_URL%\"}"; SET_DATA_URL="${SET_DATA_URL#\"}"
SET_DATA_URL="${SET_DATA_URL%\'}"; SET_DATA_URL="${SET_DATA_URL#\'}"
SET_DATA_SHEET="${SET_DATA_SHEET%\"}"; SET_DATA_SHEET="${SET_DATA_SHEET#\"}"
SET_DATA_SHEET="${SET_DATA_SHEET%\'}"; SET_DATA_SHEET="${SET_DATA_SHEET#\'}"
if [[ ! "$SET_DATA_URL" =~ ^https://docs\.google\.com/spreadsheets/d/([A-Za-z0-9_-]+)(/|$) ]]; then
  echo "❌ SET_DATA_URL ต้องเป็น URL ของ Google Sheets ที่เข้าถึงได้ด้วยลิงก์" >&2
  exit 1
fi
SHEET_ID="${BASH_REMATCH[1]}"
[[ -n "$SET_DATA_SHEET" ]] || { echo "❌ SET_DATA_SHEET ว่าง" >&2; exit 1; }

mkdir -p "$DOWNLOAD_DIR"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tfos.XXXXXX")"
TMP_SNAPSHOT="$TMP_DIR/snapshot.xlsx"
TSV="$TMP_DIR/snapshot.tsv"
TARGETS="$TMP_DIR/targets.txt"
API_TSV="$TMP_DIR/market.tsv"
API_WARNINGS="$TMP_DIR/api-warnings.txt"
TV_TSV="$TMP_DIR/tradingview.tsv"
TV_WARNINGS="$TMP_DIR/tradingview-warnings.txt"
CLASSIFIED="$TMP_DIR/classified.tsv"
: > "$API_TSV"
: > "$API_WARNINGS"
: > "$TV_TSV"
: > "$TV_WARNINGS"

echo "📥 ดาวน์โหลดข้อมูลล่าสุดจาก Reference Sheet..."
curl --fail --location --silent --show-error --max-time 30 \
  -H 'Cache-Control: no-cache, no-store, max-age=0' \
  -H 'Pragma: no-cache' -H 'Expires: 0' \
  "https://docs.google.com/spreadsheets/d/${SHEET_ID}/export?format=xlsx" \
  --output "$TMP_SNAPSHOT" || {
    echo "❌ ดาวน์โหลดไม่สำเร็จ; ไม่ใช้ snapshot เก่าแทน" >&2
    exit 1
  }
[[ -s "$TMP_SNAPSHOT" ]] || { echo "❌ ไฟล์ snapshot ว่าง" >&2; exit 1; }

if ! python3 - "$TMP_SNAPSHOT" "$SET_DATA_SHEET" "$TSV" <<'PY'
import math
import sys
from zipfile import BadZipFile
import openpyxl

source, sheet_name, out_path = sys.argv[1:]
required = {
    "AKA", "GROUP", "PRICE", "TREND(W)", "TREND(D)", "TREND(4H)", "TREND(1H)",
    "RSI(W)", "RSI(D)", "RSI(4H)", "RSI(1H)", "MACD_HIST_DELTA(W)",
    "RELATIVE_STRENGTH(W)", "RELATIVE_STRENGTH(D)",
    "RELATIVE_STRENGTH(4H)", "RELATIVE_STRENGTH(1H)", "ACTION",
    "EMA9(W)", "EMA21(W)", "SIGNAL_VOLUME(W)", "SIGNAL_VOLUME(D)",
    "SIGNAL_VOLUME(4H)", "SIGNAL_VOLUME(1H)", "ENTRY_ZONE(4H)",
    "ENTRY_TRIGGER(1H)", "LAST_CANDLE", "UPDATED",
}
try:
    wb = openpyxl.load_workbook(source, read_only=True, data_only=True)
except (OSError, BadZipFile, openpyxl.utils.exceptions.InvalidFileException) as exc:
    print(f"❌ เปิด snapshot XLSX ไม่สำเร็จ ({type(exc).__name__}: {exc})", file=sys.stderr)
    raise SystemExit(1)
try:
    if sheet_name not in wb.sheetnames:
        print(f"❌ ไม่พบชีต {sheet_name!r}; มี: {', '.join(wb.sheetnames)}", file=sys.stderr)
        raise SystemExit(1)
    ws = wb[sheet_name]
    rows = ws.iter_rows(values_only=True)
    headers = [str(v).strip() if v is not None else "" for v in next(rows, ())]
    missing = sorted(required - set(headers))
    if missing:
        print("❌ ขาดคอลัมน์: " + ", ".join(missing), file=sys.stderr)
        raise SystemExit(1)
    idx = {name: headers.index(name) for name in headers if name}
    seen, count, problems, data = set(), 0, [], []
    for excel_row, row in enumerate(rows, start=2):
        if not row or not any(v is not None and str(v).strip() for v in row):
            continue
        count += 1
        def cell(name):
            pos = idx[name]
            return row[pos] if pos < len(row) else None
        symbol = str(cell("AKA") or "").strip().upper()
        if not symbol or symbol in seen or not all(ch.isalnum() or ch in "._&-" for ch in symbol):
            problems.append(f"แถว {excel_row}: AKA ว่าง/ซ้ำ/รูปแบบไม่ถูกต้อง")
        seen.add(symbol)
        if not str(cell("GROUP") or "").strip():
            problems.append(f"แถว {excel_row}: GROUP ว่าง")
        for col in ("PRICE", "MACD_HIST_DELTA(W)", "RSI(W)", "RSI(D)", "RSI(4H)", "RSI(1H)"):
            try:
                value = float(cell(col))
                if not math.isfinite(value) or (col == "PRICE" and value <= 0) or (
                    col.startswith("RSI(") and not 0 <= value <= 100
                ):
                    raise ValueError
            except (TypeError, ValueError, OverflowError):
                problems.append(f"แถว {excel_row}: {col} ไม่ถูกต้อง")
        for col in ("TREND(W)", "TREND(D)", "TREND(4H)", "TREND(1H)",
                    "RELATIVE_STRENGTH(W)", "RELATIVE_STRENGTH(D)",
                    "RELATIVE_STRENGTH(4H)", "RELATIVE_STRENGTH(1H)"):
            if not str(cell(col) or "").strip():
                problems.append(f"แถว {excel_row}: {col} ว่าง")
        data.append(row)
    if not count:
        problems.append("ไม่พบแถวข้อมูล")
    if problems:
        print(f"❌ พบข้อผิดพลาด {len(problems)} รายการ:", file=sys.stderr)
        for problem in problems[:20]:
            print("  - " + problem, file=sys.stderr)
        raise SystemExit(1)
    def serialize(value):
        if value is None:
            return ""
        if hasattr(value, "isoformat"):
            return value.isoformat(sep=" ") if hasattr(value, "hour") else value.isoformat()
        return str(value).replace("\t", " ").replace("\r", " ").replace("\n", " ")
    with open(out_path, "w", encoding="utf-8") as out:
        out.write("\t".join(headers) + "\n")
        for row in data:
            out.write("\t".join(serialize(v) for v in row) + "\n")
    print(f"ชีต: {sheet_name}")
    print(f"จำนวนแถวข้อมูล: {count}")
finally:
    wb.close()
PY
then
  exit 1
fi
mv "$TMP_SNAPSHOT" "$SNAPSHOT"
echo "✅ ดาวน์โหลด snapshot: $SNAPSHOT"
echo "✅ โครงสร้างและข้อมูลพื้นฐานผ่านการตรวจสอบ"

cat > "$TMP_DIR/mptm.awk" <<'AWK'
BEGIN { FS = "\t"; OFS = "\t" }
function v(r, name) { return data[r, col[name]] }
function num(s) { return s ~ /^[+-]?(([0-9]+([.][0-9]*)?)|([.][0-9]+))([eE][+-]?[0-9]+)?$/ }
function n(r, name) { return num(v(r,name)) ? v(r,name)+0 : 0 }
function buy(r,t,s) { s=toupper(v(r,"SIGNAL_VOLUME(" t ")")); return s ~ /(^|[^[:alnum:]_])BUY([^[:alnum:]_]|$)/ }
function candidate(r) {
 return toupper(v(r,"TREND(W)"))=="UP" && toupper(v(r,"TREND(D)"))=="UP" &&
 num(v(r,"RSI(W)")) && n(r,"RSI(W)")>50 &&
 num(v(r,"MACD_HIST_DELTA(W)")) && n(r,"MACD_HIST_DELTA(W)")>0 &&
 num(v(r,"RSI(D)")) && n(r,"RSI(D)")<70 &&
 num(v(r,"EMA9(W)")) && num(v(r,"EMA21(W)")) && n(r,"EMA9(W)")>n(r,"EMA21(W)") &&
 (buy(r,"W") || buy(r,"D") || buy(r,"4H") || buy(r,"1H"))
}
function cmb(r,t,i,s) {
 s=0
 for(i=1;i<=4;i++) {
  t=(i==1?"W":i==2?"D":i==3?"4H":"1H")
  if(buy(r,t) && toupper(v(r,"TREND(" t ")"))=="UP") s++
 }
 return s
}
function status(r,trigger,words,cnt,i,entry,block) {
 if(num(v(r,"RSI(D)")) && n(r,"RSI(D)")>=70) return "OVEREXTENDED"
 entry=0; block=0
 cnt=split(toupper(v(r,"ENTRY_TRIGGER(1H)")),words,/[^A-Z]+/)
 for(i=1;i<=cnt;i++) {
  if(words[i]=="BUY" || words[i]=="TRIGGER" || words[i]=="ENTRY") entry=1
  if(words[i]=="WAIT" || words[i]=="RETEST" || words[i]=="NO") block=1
 }
 if(candidate(r) && entry && !block) return "BUY_CONFIRMED"
 if(toupper(v(r,"TREND(W)"))=="UP" && toupper(v(r,"TREND(D)"))=="UP" &&
    toupper(v(r,"TREND(4H)"))=="UP" && toupper(v(r,"TREND(1H)"))=="UP" &&
    num(v(r,"RSI(1H)")) && n(r,"RSI(1H)")<50) return "PULLBACK_ZONE"
 if(candidate(r)) return "EARLY_WATCH"
 return "WAIT_RETEST"
}
function add(cat,r,key) { cnt[cat]++; list[cat,cnt[cat]]=r; skey[r]=(key=="MACD"?n(r,"MACD_HIST_DELTA(W)"):cmb(r)); }
function sort(cat,i,j,r) {
 for(i=2;i<=cnt[cat];i++) {
  r=list[cat,i]; j=i-1
  while(j>=1 && (skey[list[cat,j]]<skey[r] || (skey[list[cat,j]]==skey[r] && list[cat,j]>r))) {
   list[cat,j+1]=list[cat,j]; j--
  }
  list[cat,j+1]=r
 }
}
function quote_md(s) { gsub(/[|]/,"\\|",s); return s }
function link(s) { return "[" s "](https://www.finnomena.com/stock/" s "/advance)" }
function metric(s,field_no,fallback) { return api[toupper(s),field_no]!=""?api[toupper(s),field_no]:fallback }
function liquidity(s,live,estimate) {
 s=toupper(s)
 live=api[s,2]!=""?api[s,2]:"⚫ N/A"
 estimate=api[s,3]
 return api[s,4]=="TRADINGVIEW" ? live " — TradingView estimate " estimate : live
}
function row(r,cat,s,vol,tr,cm,i,t) {
 s=toupper(v(r,"AKA"))
 if(cat=="PULLBACK") {
  vol=""; tr=""; cm=""
  for(i=1;i<=4;i++) {
   t=(i==1?"W":i==2?"D":i==3?"4H":"1H")
   vol=vol (buy(r,t)?"🟢":"⚪")
   tr=tr (toupper(v(r,"TREND(" t ")"))=="UP"?"🟢":"🔴")
   cm=cm (buy(r,t) && toupper(v(r,"TREND(" t ")"))=="UP"?"✅":"❌")
  }
  printf "| %s | %s | %s | %s | %.4f | %s (%d/4) | %s (%d/4) | %s (%d/4) | %s | %s |\n",link(s),quote_md(v(r,"GROUP")),quote_md(v(r,"RSI(W)")),quote_md(v(r,"RSI(1H)")),n(r,"PRICE"),vol,scorebuy(r),tr,scoreup(r),cm,cmb(r),liquidity(s),metric(s,3,"⚫ N/A")
 } else if(cat=="OVEREXTENDED") {
  printf "| %s | %s | %s | %s |\n",link(s),quote_md(v(r,"GROUP")),liquidity(s),metric(s,3,"⚫ N/A")
 } else {
  printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n",link(s),quote_md(v(r,"GROUP")),quote_md(v(r,"RSI(W)")),quote_md(v(r,"RSI(D)")),quote_md(v(r,"MACD_HIST_DELTA(W)")),v(r,"PRICE"),liquidity(s),metric(s,3,"⚫ N/A")
 }
}
function scorebuy(r,t,i,s) { s=0; for(i=1;i<=4;i++){t=(i==1?"W":i==2?"D":i==3?"4H":"1H"); if(buy(r,t))s++} return s}
function scoreup(r,t,i,s) { s=0; for(i=1;i<=4;i++){t=(i==1?"W":i==2?"D":i==3?"4H":"1H"); if(toupper(v(r,"TREND(" t ")"))=="UP")s++} return s}
function signals(r,kind,i,t,result,count) {
 result="";count=0
 for(i=1;i<=4;i++){
  t=(i==1?"W":i==2?"D":i==3?"4H":"1H")
  if(kind=="VOL"){if(buy(r,t)){result=result "🟢";count++}else result=result "⚪"}
  else if(kind=="TREND"){if(toupper(v(r,"TREND(" t ")"))=="UP"){result=result "🟢";count++}else result=result "🔴"}
  else {if(buy(r,t)&&toupper(v(r,"TREND(" t ")"))=="UP"){result=result "✅";count++}else result=result "❌"}
 }
 return result " (" count "/4)"
}
function specified_row(r,s) {
 s=toupper(v(r,"AKA"))
 printf "| %s | %s | %s | %s | %.4f | %s | %s | %s | %s | %s |\n",link(s),v(r,"GROUP"),v(r,"RSI(W)"),v(r,"RSI(1H)"),n(r,"PRICE"),signals(r,"VOL"),signals(r,"TREND"),signals(r,"CMB"),liquidity(s),metric(s,3,"⚫ N/A")
}
function placeholder(count,i) { printf "|"; for(i=1;i<=count;i++)printf " — |"; print "" }
function header_normal() { print "| หุ้น | GROUP | RSI(W) | RSI(D) | MACD_D | ราคา | Liquidity | Avg Turnover 20D* |"; print "|---|---|---:|---:|---:|---:|---|---:|" }
function emit_report(cat,title,limit,kind,i,shown) {
 print ""; print title
 if(kind=="OVEREXTENDED") { print "| หุ้น | GROUP | Liquidity | Avg Turnover 20D* |"; print "|---|---|---|---:|"; if(!cnt[cat])placeholder(4); else for(i=1;i<=cnt[cat];i++)row(list[cat,i],kind); return }
 if(kind=="PULLBACK") { print "| หุ้น | GROUP | RSI(W) | RSI(1H) | ราคา | VOL (x/4) | TREND (x/4) | CMB (x/4) | Liquidity | Avg Turnover 20D* |"; print "|---|---|---:|---:|---:|---|---|---|---|---:|" }
 else header_normal()
 shown=(limit && cnt[cat]>limit?limit:cnt[cat])
 if(!shown)placeholder(kind=="PULLBACK"?10:8)
 for(i=1;i<=shown;i++)row(list[cat,i],kind)
}
{
 if(FNR==1){for(i=1;i<=NF;i++)col[$i]=i;next}
 if(NF<2)next
 r=++rows
 for(i=1;i<=NF;i++)data[r,i]=$i
 symbol_row[toupper(v(r,"AKA"))]=r
}
END {
 for(r=1;r<=rows;r++){
  cat=status(r)
  add(cat,r,(cat=="PULLBACK_ZONE"?"SCORE":"MACD"))
  status_by_symbol[toupper(v(r,"AKA"))]=cat
  if(candidate(r))add("CANDIDATE",r,"MACD")
 }
 sort("BUY_CONFIRMED");sort("EARLY_WATCH");sort("PULLBACK_ZONE");sort("CANDIDATE")
 if(action=="targets") {
  if(command=="UPDATE" && selected=="") {
   r=symbol_row["ADVANC"]
   if(!r || v(r,"LAST_CANDLE")=="" || v(r,"UPDATED")==""){print "❌ ไม่พบแถว ADVANC หรือ timestamp ไม่ครบ" > "/dev/stderr"; exit 1}
  }
  if(selected!="") {
   count=split(selected,syms,"-")
   for(i=1;i<=count;i++){r=symbol_row[toupper(syms[i])]; if(!r){print "❌ ไม่พบใน snapshot: " syms[i] > "/dev/stderr";exit 1}; if(!v(r,"LAST_CANDLE") || !v(r,"UPDATED")){print "❌ timestamp ไม่ครบ: " syms[i] > "/dev/stderr";exit 1}; print toupper(syms[i])}
  } else {
   if(command=="UPDATE"){for(i=1;i<=cnt["BUY_CONFIRMED"];i++)targets[toupper(v(list["BUY_CONFIRMED",i],"AKA"))]=1;for(i=1;i<=10&&i<=cnt["EARLY_WATCH"];i++)targets[toupper(v(list["EARLY_WATCH",i],"AKA"))]=1;for(i=1;i<=10&&i<=cnt["PULLBACK_ZONE"];i++)targets[toupper(v(list["PULLBACK_ZONE",i],"AKA"))]=1;for(i=1;i<=cnt["OVEREXTENDED"];i++)targets[toupper(v(list["OVEREXTENDED",i],"AKA"))]=1}
   else for(i=1;i<=20&&i<=cnt["CANDIDATE"];i++)targets[toupper(v(list["CANDIDATE",i],"AKA"))]=1
   for(r=1;r<=rows;r++)if(targets[toupper(v(r,"AKA"))])print toupper(v(r,"AKA"))
  }
  exit
 }
 if(api_file!=""){while((getline line < api_file)>0){split(line,fields,"\t");api[toupper(fields[1]),2]=fields[2];api[toupper(fields[1]),3]=fields[3];api[toupper(fields[1]),4]=fields[4]}close(api_file)}
 if(action=="classified"){for(r=1;r<=rows;r++)print toupper(v(r,"AKA")),status_by_symbol[toupper(v(r,"AKA"))];exit}
 if(command=="UPDATE" && selected!=""){
  count=split(selected,syms,"-")
  for(i=1;i<=count;i++){r=symbol_row[toupper(syms[i])];print "AKA         : " toupper(v(r,"AKA"));print "LAST_CANDLE : " v(r,"LAST_CANDLE");print "UPDATED     : " v(r,"UPDATED");print "GROUP       : " v(r,"GROUP");print ""}
  print "🔵 SPECIFIED STOCK — " count " รายการ"
  print "| AKA | GROUP | RSI(W) | RSI(1H) | ราคา | VOL (x/4) | TREND (x/4) | CMB (x/4) | Liquidity | Avg Turnover 20D* |"
  print "|---|---|---:|---:|---:|---|---|---|---|---:|"
  for(i=1;i<=count;i++){r=symbol_row[toupper(syms[i])];j=i-1;while(j>=1 && cmb(selected_rows[j])<cmb(r)){selected_rows[j+1]=selected_rows[j];j--}selected_rows[j+1]=r}
  for(i=1;i<=count;i++)specified_row(selected_rows[i])
  exit
 }
 if(command=="CANDIDATE"){print "ผลการค้นหา CANDIDATE (PRE-ENTRY-Like Pattern) — " (cnt["CANDIDATE"]+0) " หุ้น";print "ผ่านเกณฑ์ CANDIDATE 7 ข้อ เรียงตาม MACD Delta (W) สูงสุด — รอ 1H Trigger ยืนยัน";print "| # | หุ้น | GROUP | ราคา (THB) | MACD Δ(W) | Entry Zone (4H) | 1H Trigger | Liquidity | Avg Turnover 20D* |";print "|---:|---|---|---:|---:|---|---|---|---:|";if(!cnt["CANDIDATE"])placeholder(9);for(i=1;i<=20&&i<=cnt["CANDIDATE"];i++){r=list["CANDIDATE",i];s=toupper(v(r,"AKA"));printf "| %d | %s | %s | %s | %s | %s | %s | %s | %s |\n",i,link(s),v(r,"GROUP"),v(r,"PRICE"),v(r,"MACD_HIST_DELTA(W)"),v(r,"ENTRY_ZONE(4H)"),v(r,"ENTRY_TRIGGER(1H)"),liquidity(s),metric(s,3,"⚫ N/A")}exit}
 r=symbol_row["ADVANC"];print "";print "สรุปข้อมูลหุ้น";print "AKA         : ADVANC 🔔";print "LAST_CANDLE : " v(r,"LAST_CANDLE");print "UPDATED     : " v(r,"UPDATED");print "GROUP       : " v(r,"GROUP")
 emit_report("BUY_CONFIRMED","🟢 BUY CONFIRMED — " (cnt["BUY_CONFIRMED"]+0) " หุ้น",0,"NORMAL")
 emit_report("EARLY_WATCH","🟡 EARLY/WATCH — " (cnt["EARLY_WATCH"]+0) " หุ้น (TOP 10)",10,"NORMAL")
 emit_report("PULLBACK_ZONE","🟠 PULLBACK ZONE — " (cnt["PULLBACK_ZONE"]+0) " หุ้น (TOP 10)",10,"PULLBACK")
 emit_report("OVEREXTENDED","🔴 OVEREXTENDED — " (cnt["OVEREXTENDED"]+0) " หุ้น",0,"OVEREXTENDED")
 print ""; print "⚪ WAIT/RETEST — " (cnt["WAIT_RETEST"]+0) " หุ้น"
}
AWK

awk -F '\t' -v action=targets -v command="$COMMAND" -v selected="$SELECTED" -f "$TMP_DIR/mptm.awk" "$TSV" > "$TARGETS"
if [[ "$COMMAND" == CANDIDATE || "$COMMAND" == UPDATE || "$SELECTED" != "" ]]; then
  TV_DIR="$DOWNLOAD_DIR/tradingview"
  while IFS= read -r symbol || [[ -n "$symbol" ]]; do
    [[ -n "$symbol" ]] || continue
    tv_csv="$TV_DIR/$symbol.csv"
    if [[ ! -f "$tv_csv" ]]; then
      echo "ไม่มี TradingView CSV สำหรับ $symbol; คาดหวังไฟล์ $TV_DIR/<AKA>.csv" >> "$TV_WARNINGS"
      continue
    fi
    if ! awk -v symbol="$symbol" '
      function parse_csv(line, fields, delimiter,    i, ch, quoted, field, count) {
        for (i in fields) delete fields[i]
        count=1; field=""; quoted=0
        for (i=1; i<=length(line); i++) {
          ch=substr(line,i,1)
          if (ch=="\"") {
            if (quoted && substr(line,i+1,1)=="\"") { field=field "\""; i++ }
            else quoted=!quoted
          } else if (ch==delimiter && !quoted) {
            fields[count++]=field; field=""
          } else field=field ch
        }
        fields[count]=field
        return count
      }
      {
        line=$0
        if (!header_found && NR<=20) {
          comma_count=parse_csv(line,comma_fields,",")
          semicolon_count=parse_csv(line,semicolon_fields,";")
          tab_count=parse_csv(line,tab_fields,"\t")
          delimiter=","; field_count=comma_count
          if (semicolon_count>field_count) { delimiter=";"; field_count=semicolon_count }
          if (tab_count>field_count) { delimiter="\t"; field_count=tab_count }
          parse_csv(line,fields,delimiter)
          time_count=0; matched_column=0
          for (i=1; i<=field_count; i++) {
            cell=tolower(fields[i]); gsub(/^[[:space:]]+|[[:space:]]+$/,"",cell)
            sub(/^[^[:alnum:]]+/,"",cell)
            if (cell=="time" || cell=="date" || cell=="datetime") time_count++
            if (index(cell,"tv avg turnover 20d thb")) {
              matched_column=i; matched_count++
            }
          }
          if (time_count && matched_count==1) {
            header_found=1; value_column=matched_column; matched_count=0
            next
          }
          matched_count=0
          next
        }
        if (header_found) {
          field_count=parse_csv(line,fields,delimiter)
          if (value_column>field_count) next
          value=fields[value_column]
          gsub(/,/,"",value)
          gsub(/^[[:space:]]+|[[:space:]]+$/,"",value)
          if (value ~ /^[-+]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][-+]?[0-9]+)?$/ && value+0>0)
            estimate=value+0
        }
      }
      END {
        if (!header_found) {
          print symbol ": ไม่พบคอลัมน์เวลาและ TV Avg Turnover 20D THB" > "/dev/stderr"
          exit 1
        }
        if (estimate<=0) {
          print symbol ": ไม่มีค่า estimate ที่เป็นตัวเลขบวก" > "/dev/stderr"
          exit 1
        }
        printf "%s\t%.10f\n",symbol,estimate
      }
    ' "$tv_csv" >> "$TV_TSV" 2>> "$TV_WARNINGS"; then
      :
    fi
  done < "$TARGETS"
  python3 - "$ENV_FILE" "$TARGETS" "$API_TSV" "$API_WARNINGS" "$TV_TSV" "$TV_WARNINGS" <<'PY'
import os, sys, time, threading, math
from datetime import datetime, timezone, timedelta
from pathlib import Path
env_path, target_path, output_path, warning_path, tv_path, tv_warning_path = sys.argv[1:]
config={}
for line in Path(env_path).read_text(encoding="utf-8").splitlines():
    line=line.strip()
    if line and not line.startswith("#") and "=" in line:
        k,v=line.split("=",1); config[k.strip()]=v.strip().strip("\"'")
symbols=list(dict.fromkeys(s.strip().upper() for s in Path(target_path).read_text().splitlines() if s.strip()))
warnings=[]
metrics={}
tv_estimates={}
def finite_number(value):
    try:
        number=float(value)
        return number if math.isfinite(number) else None
    except (TypeError,ValueError,OverflowError):
        return None
for line in Path(tv_path).read_text(encoding="utf-8").splitlines():
    symbol,value=line.split("\t",1)
    estimate=finite_number(value)
    if estimate is not None and estimate>0:
        tv_estimates[symbol]=f"≈ ฿{estimate:,.2f}"
with Path(tv_warning_path).open(encoding="utf-8") as tv_warnings:
    warnings.extend(line.rstrip("\n") for line in tv_warnings if line.strip())
app_id=config.get("SETTRADE_APP_ID",""); secret=config.get("SETTRADE_APP_SECRET","")
if symbols and (not app_id or not secret):
    warnings.append("ไม่ได้กำหนด " + ", ".join(k for k,v in (("SETTRADE_APP_ID",app_id),("SETTRADE_APP_SECRET",secret)) if not v) + " ใน .env")
elif symbols:
    try:
        from settrade_v2 import Investor
        from settrade_v2.errors import SettradeError
        from requests.exceptions import RequestException
    except ImportError as exc:
        warnings.append(f"โหลด Settrade SDK ไม่สำเร็จ ({type(exc).__name__})")
    else:
        app_code=config.get("SETTRADE_APP_CODE","SANDBOX") or "SANDBOX"
        broker_id=config.get("SETTRADE_BROKER_ID","SANDBOX") or "SANDBOX"
        def settrade_error(exc):
            details=[]
            status=getattr(exc,"status_code",None)
            code=getattr(exc,"code",None)
            message=str(exc).replace(app_id,"[REDACTED]").replace(secret,"[REDACTED]")
            if status is not None: details.append(f"HTTP {status}")
            if code: details.append(str(code))
            if message: details.append(message)
            return ": ".join(details) or type(exc).__name__
        try:
            investor=Investor(app_id=app_id, app_secret=secret,
                app_code=app_code, broker_id=broker_id, is_auto_queue=False)
        except (OSError,RuntimeError,TimeoutError,ValueError,RequestException,SettradeError) as exc:
            investor=None
            warnings.append("เชื่อมต่อ Settrade/login ไม่สำเร็จ: " + settrade_error(exc))
        started=time.monotonic()
        session_relogin_used=False
        for symbol in symbols if investor is not None else []:
            state={"info":None,"book":None}
            event=threading.Event()
            feeds=[]
            def info_cb(message):
                if message.get("is_success") and isinstance(message.get("data"),dict):
                    value=finite_number(message["data"].get("total_value"))
                    if value is not None and value >= 0: state["info"]={"total_value":value}
                else:
                    state["feed_error"]=str(message.get("message") or "info feed rejected")
                    event.set()
                event.set() if state["info"] is not None and state["book"] is not None else None
            def book_cb(message):
                if message.get("is_success") and isinstance(message.get("data"),dict):
                    data=message["data"]
                    parsed={}
                    for level in range(1,11):
                        bid_volume=finite_number(data.get(f"bid_volume{level}"))
                        ask_volume=finite_number(data.get(f"ask_volume{level}"))
                        if bid_volume is None or ask_volume is None or bid_volume < 0 or ask_volume < 0: break
                        parsed[f"bid_volume{level}"]=bid_volume
                        parsed[f"ask_volume{level}"]=ask_volume
                    bid_price=finite_number(data.get("bid_price1"))
                    ask_price=finite_number(data.get("ask_price1"))
                    if len(parsed)==20 and bid_price is not None and ask_price is not None and bid_price >= 0 and ask_price >= 0 and (not bid_price or not ask_price or ask_price >= bid_price):
                        parsed["bid_price1"]=bid_price
                        parsed["ask_price1"]=ask_price
                        state["book"]=parsed
                    else:
                        state["feed_error"]="invalid bid/offer data"
                else:
                    state["feed_error"]=str(message.get("message") or "bid/offer feed rejected")
                    event.set()
                event.set() if state["info"] is not None and state["book"] is not None else None
            try:
                for attempt in range(2):
                    try:
                        realtime=investor.RealtimeDataConnection()
                        a=realtime.subscribe_price_info(symbol,info_cb); feeds.append(a); a.start()
                        b=realtime.subscribe_bid_offer(symbol,book_cb); feeds.append(b); b.start()
                        break
                    except SettradeError as exc:
                        for feed in feeds:
                            try: feed.stop()
                            except (OSError,RuntimeError) as stop_exc: warnings.append(f"{symbol}: ปิด feed ไม่สำเร็จ ({type(stop_exc).__name__})")
                        feeds=[]
                        if getattr(exc,"status_code",None)!=401 or session_relogin_used or attempt>0:
                            raise
                        session_relogin_used=True
                        warnings.append(f"{symbol}: Settrade session ตอบ 401; login ใหม่และลอง realtime ซ้ำหนึ่งครั้ง")
                        investor=Investor(app_id=app_id,app_secret=secret,
                            app_code=app_code,broker_id=broker_id,is_auto_queue=False)
                event.wait(max(0,min(20,120-(time.monotonic()-started))))
            except (OSError,RuntimeError,TimeoutError,ValueError,RequestException,SettradeError) as exc:
                warnings.append(f"{symbol}: realtime feed ล้มเหลว ({settrade_error(exc)})")
            finally:
                for feed in feeds:
                    try: feed.stop()
                    except (OSError,RuntimeError) as exc: warnings.append(f"{symbol}: ปิด feed ไม่สำเร็จ ({type(exc).__name__})")
            if state.get("feed_error"):
                safe_feed_error=state["feed_error"].replace(app_id,"[REDACTED]").replace(secret,"[REDACTED]")
                warnings.append(f"{symbol}: Settrade ปฏิเสธ/ส่งข้อมูล realtime ไม่ถูกต้อง ({safe_feed_error})")
            info=state["info"] or {}; book=state["book"] or {}
            if state["info"] is None: warnings.append(f"{symbol}: ไม่ได้รับข้อมูลมูลค่าซื้อขายที่ถูกต้อง")
            if state["book"] is None: warnings.append(f"{symbol}: ไม่ได้รับข้อมูล bid/offer ที่ถูกต้อง")
            if state["info"] is not None and state["book"] is not None:
                info=state["info"] or {}
                book=state["book"] or {}
                turnover=info.get("total_value")
                bid=book.get("bid_price1"); ask=book.get("ask_price1")
                bids=[]; asks=[]
                for level in range(1,11):
                    try: bids.append(float(book.get(f"bid_volume{level}") or 0))
                    except (TypeError,ValueError,OverflowError): bids.append(0)
                    try: asks.append(float(book.get(f"ask_volume{level}") or 0))
                    except (TypeError,ValueError,OverflowError): asks.append(0)
                try: spread=float(ask)-float(bid) if bid and ask else None
                except (TypeError,ValueError,OverflowError): spread=None
                def money(x):
                    try:
                        number=float(x)
                        return f"฿{number:,.2f}" if math.isfinite(number) else "N/A"
                    except (TypeError,ValueError,OverflowError): return "N/A"
                liq=f"Turnover {money(turnover)} | Bid1 {money(bid)} / Ask1 {money(ask)} | Spread {money(spread)} | Bid10 {sum(bids):,.0f} / Ask10 {sum(asks):,.0f}"
                metrics[symbol]=[liq,"⚫ N/A"]
        try:
            if investor is None:
                raise RuntimeError("ข้าม Historical API เพราะเชื่อมต่อ Settrade/login ไม่สำเร็จ")
            market=investor.MarketData()
            today=datetime.now(timezone(timedelta(hours=7))).date()
            for symbol in symbols:
                if time.monotonic()-started>=120:
                    warnings.append("Historical API: หมดเวลาประมวลผล; หุ้นที่เหลือเป็น N/A")
                    break
                if symbol in tv_estimates:
                    continue
                try: candles=market.get_candlestick(symbol,"1d",limit=40)
                except (OSError,RuntimeError,TimeoutError,ValueError,RequestException,SettradeError) as exc:
                    warnings.append(f"{symbol}: Historical API ล้มเหลว ({type(exc).__name__})")
                    continue
                if not isinstance(candles,dict) or not all(isinstance(candles.get(k),list) for k in ("time","close","volume")):
                    warnings.append(f"{symbol}: Historical API ส่งโครงสร้างแท่งรายวันไม่ครบ")
                    continue
                values=candles.get("value")
                values=values if isinstance(values,list) else []
                days=[]
                for index,(stamp,close,volume) in enumerate(zip(candles["time"],candles["close"],candles["volume"])):
                    try:
                        dt=datetime.fromtimestamp(float(stamp),timezone.utc).astimezone(timezone(timedelta(hours=7))).date()
                        close=float(close); volume=float(volume)
                    except (TypeError,ValueError,OverflowError,OSError):
                        continue
                    if dt<today and volume>0 and close>0 and math.isfinite(close) and math.isfinite(volume):
                        try:
                            reported_value=float(values[index])
                            value_valid=math.isfinite(reported_value) and reported_value>0
                        except (IndexError,TypeError,ValueError,OverflowError):
                            value_valid=False
                        days.append((dt,close*volume,value_valid))
                days=sorted(days,key=lambda day:day[0])[-20:]
                if len(days)<20:
                    warnings.append(f"{symbol}: มีวันซื้อขายย้อนหลังที่ใช้ได้เพียง {len(days)}/20 วัน")
                    continue
                avg=sum(turnover for _,turnover,_ in days)/20
                metrics.setdefault(symbol,["⚫ N/A","⚫ N/A"])[1]=f"≈ ฿{avg:,.2f}"
                invalid_values=sum(not valid for _,_,valid in days)
                if invalid_values:
                    warnings.append(f"Historical data: {symbol}: ฟิลด์ value ผิดปกติ {invalid_values}/20 วัน; ใช้ close × volume เป็นค่าประมาณแทน")
        except (OSError,RuntimeError,TimeoutError,ValueError,RequestException,SettradeError) as exc:
            warnings.append(f"Historical API ไม่พร้อมใช้งาน ({type(exc).__name__})")
for symbol,estimate in tv_estimates.items():
    values=metrics.setdefault(symbol,["⚫ N/A","⚫ N/A",""])
    while len(values)<3: values.append("")
    values[1]=estimate
    values[2]="TRADINGVIEW"
with open(output_path,"w",encoding="utf-8") as out:
    for symbol,fields in metrics.items(): out.write(symbol+"\t"+"\t".join(fields[:2])+"\t"+(fields[2] if len(fields)>2 else "")+"\n")
with open(warning_path,"w",encoding="utf-8") as out:
    if tv_estimates:
        out.write("TradingView Pine estimate: CSV export; mean of close × volume for the previous 20 completed daily bars. Symbols: "+", ".join(sorted(tv_estimates))+"\n")
    for warning in warnings: out.write(warning.replace("\n"," ")+"\n")
PY
fi

awk -F '\t' -v action=report -v command="$COMMAND" -v selected="$SELECTED" -v api_file="$API_TSV" -f "$TMP_DIR/mptm.awk" "$TSV" > "$TMP_DIR/report.md"
awk -F '\t' -v action=classified -v api_file="$API_TSV" -f "$TMP_DIR/mptm.awk" "$TSV" > "$CLASSIFIED"
cat "$TMP_DIR/report.md"

python3 - "$SNAPSHOT" "$SET_DATA_SHEET" "$REPORT_XLSX" "$SET_DATA_URL" "$CLASSIFIED" "$API_TSV" <<'PY'
import sys, os
from datetime import datetime, timezone, timedelta
import openpyxl
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

source, sheet_name, output, source_url, classified_path, api_path=sys.argv[1:]
wb_src=openpyxl.load_workbook(source,read_only=True,data_only=True)
ws_src=wb_src[sheet_name]
headers=[str(v).strip() if v is not None else "" for v in next(ws_src.iter_rows(min_row=1,max_row=1,values_only=True))]
idx={h:i for i,h in enumerate(headers) if h}
rows=[r for r in ws_src.iter_rows(min_row=2,values_only=True) if r and any(v is not None and str(v).strip() for v in r)]
wb_src.close()
status={}
for line in open(classified_path,encoding="utf-8"):
    symbol, value=line.rstrip("\n").split("\t",1); status[symbol]=value
market={}
for line in open(api_path,encoding="utf-8"):
    parts=line.rstrip("\n").split("\t")
    if len(parts)>=3: market[parts[0]]=(parts[1],parts[2],parts[3] if len(parts)>3 else "")
report_wb=openpyxl.load_workbook(output) if os.path.exists(output) else openpyxl.Workbook()
for extra in list(report_wb.sheetnames):
    if extra not in ("Latest Snapshot","Master Signal Log","REF."):
        del report_wb[extra]
for name in ("Latest Snapshot","Master Signal Log","REF."):
    if name not in report_wb.sheetnames: report_wb.create_sheet(name)
latest=report_wb["Latest Snapshot"]
for merged in list(latest.merged_cells.ranges):
    latest.unmerge_cells(str(merged))
latest.delete_rows(1,latest.max_row)
master=report_wb["Master Signal Log"]
if master.max_row==1 and master["A1"].value is None: master.delete_rows(1,1)
ref=report_wb["REF."]
for merged in list(ref.merged_cells.ranges):
    ref.unmerge_cells(str(merged))
ref.delete_rows(1,ref.max_row)
title_fill=PatternFill("solid",fgColor="183A5A")
white=Font(color="FFFFFF",bold=True)
status_fill={"BUY_CONFIRMED":"70AD47","EARLY_WATCH":"FFD966","PULLBACK_ZONE":"F4B183","OVEREXTENDED":"F8696B","WAIT_RETEST":"D9E1F2"}
def write_sheet_header(ws,title,cols):
    ws.append([title])
    ws.merge_cells(start_row=1,start_column=1,end_row=1,end_column=len(cols))
    c=ws.cell(1,1);c.fill=title_fill;c.font=white;c.alignment=Alignment(horizontal="center")
    ws.append(cols)
    for cell in ws[2]:
        cell.fill=title_fill;cell.font=white;cell.alignment=Alignment(horizontal="center",wrap_text=True)
def linkify(cell,symbol):
    cell.hyperlink=f"https://www.finnomena.com/stock/{symbol}/advance"
    cell.style="Hyperlink"
def to_num(v):
    try:return float(v)
    except (TypeError,ValueError):return v
selected_cols=["UPDATED","AKA","GROUP","PRICE","LAST_CANDLE","TREND(W)","TREND(D)","RSI(W)","RSI(D)","MACD_HIST_DELTA(W)","ENTRY_ZONE(4H)","ENTRY_TRIGGER(1H)","ACTION"]
write_sheet_header(latest,"Latest Snapshot",selected_cols+["MPTM Status","Recommendation","Liquidity","Avg Turnover 20D*"])
now=datetime.now(timezone(timedelta(hours=7))).strftime("%Y-%m-%d %H:%M:%S")
append_rows=[]
for r in rows:
    def get(k): return r[idx[k]] if k in idx and idx[k]<len(r) else None
    symbol=str(get("AKA") or "").upper()
    st=status.get(symbol,"WAIT_RETEST")
    liq,avg,source=market.get(symbol,("⚫ N/A","⚫ N/A",""))
    if source=="TRADINGVIEW":
        liq += " — TradingView estimate " + avg
    vals=[get(k) for k in selected_cols]
    advice={"BUY_CONFIRMED":"รอพิจารณาตาม 1H Trigger; ไม่ใช่คำสั่งซื้อขาย","EARLY_WATCH":"เฝ้ารอ 1H Trigger","PULLBACK_ZONE":"ติดตามการพักฐาน","OVEREXTENDED":"หลีกเลี่ยงการไล่ราคา","WAIT_RETEST":"รอ RETEST/สัญญาณยืนยัน"}.get(st,"รอตรวจสอบ")
    latest.append(vals+[st,advice,liq,avg])
    cell=latest.cell(latest.max_row,2)
    linkify(cell,symbol)
    latest.cell(latest.max_row,4).number_format="0.0000"
    append_rows.append([now]+vals+[st,advice,liq,avg])
log_cols=["Run Timestamp"]+selected_cols+["MPTM Status","Recommendation","Liquidity","Avg Turnover 20D*"]
if master.max_row==1 and all(cell.value is None for cell in master[1]):
    master.delete_rows(1,master.max_row)
    write_sheet_header(master,"Master Signal Log (Append-Only)",log_cols)
elif master.cell(1,1).value!="Master Signal Log (Append-Only)" or [
    master.cell(2,c).value for c in range(1,len(log_cols)+1)
]!=log_cols:
    raise SystemExit("❌ โครงสร้าง Master Signal Log เดิมไม่ตรง; หยุดเพื่อรักษาประวัติเดิม")
for row in append_rows:
    master.append(row)
    linkify(master.cell(master.max_row,3),str(row[2]).upper())
ref.append(["Item","Reference"])
ref.append(["Reference Sheet",source_url])
ref["A1"].fill=title_fill;ref["B1"].fill=title_fill;ref["A1"].font=white;ref["B1"].font=white
ref["B2"].hyperlink=source_url
for ws in (latest,master,ref):
    ws.freeze_panes="A3" if ws is not ref else "A2"
    ws.auto_filter.ref=ws.dimensions
    for col in range(1,ws.max_column+1):
        letter=get_column_letter(col)
        ws.column_dimensions[letter].width=min(42,max(14,max((len(str(ws.cell(row,col).value or "")) for row in range(1,min(ws.max_row,40)+1)),default=12)+2))
        for cell in ws[letter]:
            cell.alignment=Alignment(vertical="top",wrap_text=True)
    if ws is not ref:
        status_col = selected_cols.__len__()+1 if ws.title=="Latest Snapshot" else log_cols.index("MPTM Status")+1
        for row_num in range(3,ws.max_row+1):
            st=ws.cell(row_num,status_col).value
            fill=PatternFill("solid",fgColor=status_fill.get(st,"FFFFFF"))
            for cell in ws[row_num]: cell.fill=fill
report_wb.save(output)
print(f"✅ Excel report: {output}")
PY

if [[ -s "$API_WARNINGS" ]]; then
  while IFS= read -r warning || [[ -n "$warning" ]]; do echo "⚠️ $warning"; done < "$API_WARNINGS"
fi
echo "⚠️ Avg Turnover 20D* เป็นค่าประมาณ ไม่ใช่มูลค่าซื้อขายจริง: Settrade ใช้ close × volume เฉลี่ย 20 วันซื้อขาย; TradingView ใช้ proxy จาก weekly close × volume เฉลี่ย 4 สัปดาห์ที่ปิดแล้ว ÷ 5"
echo "⚠️ พบคอลัมน์เวลาอ้างอิง แต่ยังไม่ได้ตรวจความสดของข้อมูล"
echo "⚠️ ไม่ได้ตรวจสอบ benchmark, ปฏิทิน/เวลาซื้อขาย, corporate actions, tick size หรือ board lot"
echo "⚠️ ใช้ signals จาก snapshot; ไม่ส่งคำสั่งซื้อขาย"
