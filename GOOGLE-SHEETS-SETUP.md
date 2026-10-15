# ตั้งค่าแหล่งข้อมูลและคำสั่ง TFOSvS (SET)

`UPDATE` และ `CANDIDATE` ใช้ Bash เป็น entrypoint โดยแต่ละครั้งจะดาวน์โหลด XLSX จาก `SET_DATA_URL` ใน `.env` เก็บไว้ที่ `downloads/All-SET-MTFS.xlsx` ตรวจ snapshot และแสดงผลใน Terminal; Bash/AWK จัดกลุ่ม signals ส่วน inline Python ใช้เฉพาะอ่าน/เขียน XLSX และเรียก Settrade API ไม่มีไฟล์ Python หรือ AWK แยกถาวร และไม่มีการคำนวณ OHLCV ใหม่

## ตั้งค่า

1. ติดตั้ง Python 3 และ dependencies:

   ```bash
   pip3 install -r requirements.txt
   ```

2. สร้าง `.env` จากตัวอย่าง:

   ```bash
   cp .env.example .env
   ```

3. กำหนด URL ของ Google Sheets และชื่อแท็บที่มี signals:

   ```dotenv
   SET_DATA_URL=https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit
   SET_DATA_SHEET=All-SET-MTFS
   ```

4. ตรวจให้แน่ใจว่า Google Sheets XLSX export อ่านได้โดยไม่ลงชื่อเข้าใช้ แล้วรันคำสั่ง:

   ```bash
   ./update.sh
   ./candidate.sh
   ```

การดาวน์โหลดและตรวจ snapshot ใช้ได้โดยไม่กำหนด Settrade credentials; หากต้องการข้อมูล Liquidity ให้กำหนด App ID และ App Secret ตามหัวข้อด้านล่าง

## การดาวน์โหลดและความเป็นส่วนตัว

ทุกครั้งที่รัน `update.sh` (รวม `UPDATE/<AKA>-<AKA>-...`) หรือ `candidate.sh` โปรแกรมจะร้องขอ XLSX ใหม่จาก Google Sheets โดยส่งคำสั่งป้องกันการใช้ HTTP cache; ไม่ใช้ snapshot เก่าแทนเมื่อการดาวน์โหลดล้มเหลว ไฟล์ที่ดาวน์โหลดสำเร็จถูกเก็บที่ `downloads/All-SET-MTFS.xlsx` ซึ่งถูก ignore โดย Git

การดาวน์โหลดต้องเข้าถึงได้โดยไม่ลงชื่อเข้าใช้ หาก workbook มีข้อมูลส่วนตัวหรือข้อมูลพอร์ต อย่าเปิด workbook นั้นเป็น Anyone-with-the-link ให้สร้างสำเนาสำหรับอ่านที่ไม่มีข้อมูลส่วนตัวและใช้ URL ของสำเนาแทน URL ถูกอ่านจาก `.env` ในเครื่องและไม่ถูกแสดงในรายงาน

## คอลัมน์ที่ต้องมี

ชื่อแท็บค่าเริ่มต้นคือ `All-SET-MTFS` และต้องมี:

| กลุ่ม | คอลัมน์ |
|---|---|
| หุ้น/กลุ่ม/ราคา/สถานะ | `AKA`, `GROUP`, `PRICE`, `ACTION` |
| Trend และ RSI | `TREND(W/D/4H/1H)`, `RSI(W/D/4H/1H)` |
| MACD และ Relative Strength | `MACD_HIST_DELTA(W)`, `RELATIVE_STRENGTH(W/D/4H/1H)` |
| คัด Candidate/แสดงรายงาน | `EMA9(W)`, `EMA21(W)`, `SIGNAL_VOLUME(W)`, `SIGNAL_VOLUME(D)`, `SIGNAL_VOLUME(4H)`, `SIGNAL_VOLUME(1H)`, `ENTRY_ZONE(4H)`, `ENTRY_TRIGGER(1H)` |

หุ้นจะเป็น Candidate เมื่อผ่านครบทุกเงื่อนไขต่อไปนี้:

1. `TREND(W) = UP`
2. `TREND(D) = UP`
3. `RSI(W) > 50`
4. `MACD_HIST_DELTA(W) > 0`
5. `RSI(D) < 70`
6. `EMA9(W) > EMA21(W)`
7. `SIGNAL_VOLUME` มีค่า `BUY` อย่างน้อยหนึ่ง timeframe จาก W/D/4H/1H

`AKA` ต้องเป็นข้อความรูปแบบ ticker และไม่ซ้ำ `GROUP`, trend และ relative-strength ต้องไม่ว่าง `PRICE` ต้องมากกว่า 0, RSI ต้องอยู่ระหว่าง 0–100 และ MACD delta ต้องเป็นตัวเลข finite หาก schema หรือข้อมูลไม่ผ่าน โปรแกรมจะแจ้งข้อผิดพลาดและไม่แสดงผลสำเร็จแทน

## คำสั่ง

- `./update.sh` หรือ `./update.sh UPDATE` — ดาวน์โหลดข้อมูลล่าสุด ประมวลผล MPTM จาก snapshot และตรวจ Liquidity (`Liquidity` กับ `Avg Turnover Estimate*`)
- `./update.sh UPDATE/PTT-AOT-CPALL` — ดาวน์โหลด snapshot ใหม่และแสดงเฉพาะ AKA ที่ระบุ; AKA ที่ไม่มีใน snapshot จะถูกรายงานและทำให้คำสั่งจบด้วย error status
- `./candidate.sh` หรือ `./candidate.sh CANDIDATE` — อ่าน snapshot Excel ที่ดาวน์โหลดล่าสุดและแสดงหุ้นที่ผ่าน PRE-ENTRY-Like Pattern ทั้ง 7 เกณฑ์

`UPDATE` ปกติเริ่มด้วยสรุปหุ้น `ADVANC` โดยอ่าน `AKA`, `LAST_CANDLE`, `UPDATED` และ `GROUP` จากแถวเดียวกันใน snapshot; ต้องมีคอลัมน์ timestamp ทั้งคู่และมีค่า หากไม่มีจะแจ้งข้อผิดพลาด จากนั้นจัดกลุ่มสถานะ MPTM จาก signals ใน snapshot เป็น `BUY CONFIRMED`, `EARLY/WATCH`, `PULLBACK ZONE`, `OVEREXTENDED` และ `WAIT/RETEST` โดยเรียง `EARLY/WATCH` ตาม `MACD_HIST_DELTA(W)` และ `PULLBACK ZONE` ตาม Combined Score; แสดง `GROUP` และชื่อตารางเป็นลิงก์ Finnomena.

`UPDATE/<AKA>-<AKA>-...` แสดงบล็อก `AKA`, `LAST_CANDLE`, `UPDATED`, `GROUP` ของแต่ละ AKA ก่อนตาราง `🔵 SPECIFIED STOCK — n รายการ` ที่มีคอลัมน์ `AKA | GROUP | RSI(W) | RSI(1H) | ราคา | VOL (x/4) | TREND (x/4) | CMB (x/4) | Liquidity | Avg Turnover Estimate*`; เรียงแถวตาม CMB score จากมากไปน้อย. AKA ที่ไม่พบหรือไม่มี timestamp จะแจ้งตามจริงและคืน error status; ไม่มีการจัดระดับ Liquidity เป็น HIGH/MEDIUM/LOW. `CANDIDATE` แสดงจำนวนผู้ผ่านทั้งหมดและตารางไม่เกิน 20 หุ้น เรียง `MACD_HIST_DELTA(W)` จากมากไปน้อย พร้อม `GROUP`, ราคา, `ENTRY_ZONE(4H)`, `ENTRY_TRIGGER(1H)`, Liquidity และ `Avg Turnover Estimate*`; ดึงข้อมูลเพิ่มเฉพาะ 20 หุ้นแรกที่แสดง

คำสั่งเหล่านี้อ่าน snapshot ล่าสุดที่ดาวน์โหลดมาเท่านั้น ไม่ได้แก้ไข Workbook ต้นทาง แต่สร้าง/อัปเดตรายงานที่ `downloads/All-SET-MTFS_output.xlsx` จำนวนสามชีท:

1. `Latest Snapshot` — signals ล่าสุดพร้อม Recommendation, สถานะ MPTM และ TREND(W)/TREND(D)
2. `Master Signal Log` — บันทึกผลแบบ append-only; หาก schema เดิมไม่ตรงจะหยุดเพื่อรักษาประวัติ
3. `REF.` — ลิงก์ Reference Sheet ต้นทาง

`WAIT/RETEST` แสดงเฉพาะหัวข้อและจำนวนหุ้น ไม่มีรายชื่อหรือตาราง และไม่เรียก Settrade สำหรับกลุ่มนี้

### TradingView turnover estimate

ระบบดึงค่า `AvgValue.Traded_30d` จาก [Thailand scanner endpoint](https://scanner.tradingview.com/thailand/scan) โดยตรงสำหรับหุ้นในรายงาน ไม่ต้อง export CSV หรือสร้าง Pine data เอง เป็นค่าเฉลี่ยย้อนหลัง 30 วันตามฟิลด์ TradingView ไม่ใช่ค่าเฉลี่ย 20 วันซื้อขาย จึงแสดงแหล่งเป็น `TradingView Screener 30D avg` และตัวเลขในคอลัมน์ `Avg Turnover Estimate*` หากไม่มีค่าจาก scanner หรือ endpoint ใช้ไม่ได้ ระบบแจ้งเหตุและลองใช้ Settrade historical estimate หากมี มิฉะนั้นแสดง `⚫ N/A`

อ้างอิงรายการฟิลด์: [TradingView Stocks fields](https://shner-elmo.github.io/TradingView-Screener/fields/stocks.html). Estimate นี้ไม่ใช่มูลค่าซื้อขายจริง และไม่ใช้แทน Bid–Ask หรือ turnover วันนี้จาก Settrade realtime

`UPDATE` ประมวลผล signals และดึงข้อมูลก่อนเริ่มแสดงรายงาน แล้วรวม Liquidity ปัจจุบันและ `Avg Turnover Estimate*` ในตาราง ไม่แสดงตาราง refresh แยกด้านล่าง คำสั่งปกติดึงเฉพาะหุ้นที่แสดงใน `BUY CONFIRMED`, `EARLY/WATCH` สูงสุด 10, `PULLBACK ZONE` สูงสุด 10 และ `OVEREXTENDED`; `WAIT/RETEST` แสดงจำนวนอย่างเดียวและไม่ดึงทั้ง Liquidity ปัจจุบันหรือข้อมูลย้อนหลัง ระบบขอ feed ปัจจุบันทีละหุ้น เปิดไม่เกิน 2 subscriptions พร้อมกันและปิดก่อนหุ้นถัดไป ส่วนข้อมูลย้อนหลังใช้ daily candles จาก Settrade สำหรับ 20 วันซื้อขายที่มี volume ก่อนวันนี้ ภายในงบเวลารวม 120 วินาที; เมื่อข้อมูลไม่ครบจะแสดง `⚫ N/A` พร้อมคำเตือน

Settrade historical turnover คำนวณเป็นค่าประมาณจาก `close × volume` เฉลี่ย 20 วันซื้อขายก่อนวันนี้ ไม่ใช่มูลค่าซื้อขายจริง เนื่องจากการทดลอง UAT พบ daily field `value` เป็นศูนย์แม้มี volume ระบบจะแจ้งจำนวนข้อมูลที่ฟิลด์นี้ผิดปกติและแสดงค่าประมาณอย่างเปิดเผย TradingView estimate ใช้ `AvgValue.Traded_30d` ซึ่งเป็น rolling average 30 วัน ไม่ใช่ค่า 20 วัน ค่าทั้งสองไม่ใช้จัดระดับ `HIGH/MEDIUM/LOW`; ตรวจฟิลด์ที่รองรับได้จาก [เอกสาร Stocks fields](https://shner-elmo.github.io/TradingView-Screener/fields/stocks.html) และ [Thailand scanner endpoint](https://scanner.tradingview.com/thailand/scan)

รายงานใช้ข้อมูล signals ที่คำนวณไว้ในชีต ไม่มีการจัดอันดับหรือคำนวณ MPTM ใหม่ การเชื่อมต่อ Settrade (ถ้ากำหนด credentials) ใช้เฉพาะ read-only market data และไม่ส่งคำสั่งซื้อขาย

## แหล่งข้อมูล Liquidity

### Settrade Open API (ตัวเลือกเสริม)

หากมีสิทธิ์ใช้งาน Open API ให้ใส่ App ID และ App Secret ใน `.env` เฉพาะเครื่องของตน:

```dotenv
SETTRADE_APP_ID=<APP_ID>
SETTRADE_APP_SECRET=<APP_SECRET>
SETTRADE_BROKER_ID=SANDBOX
SETTRADE_APP_CODE=SANDBOX
```

คำสั่งจะสมัครรับเฉพาะ read-only market feeds ในวันจันทร์–ศุกร์ ช่วง 10:00–12:30 และ 14:30–16:30 น. ตามเวลาไทย (ตรวจเฉพาะวันและเวลา ไม่ตรวจปฏิทินวันหยุด SET): มูลค่าซื้อขายสะสมของวันจาก `InfoV3.total_value` และ order book bid/ask 10 ระดับจาก `BidOfferV3` ผ่าน SDK `settrade-v2` จากนั้นแสดงมูลค่าซื้อขายวันนี้, ราคา bid/ask ระดับแรก, spread และผลรวมปริมาณ bid/ask 10 ระดับ ไม่มีการจัดระดับ HIGH/MEDIUM/LOW และไม่อนุมานค่าที่ไม่มีจาก snapshot หรือ cache เก่า ระหว่างช่วงตลาดเปิด หากข้อมูลไม่ครบจะแสดง N/A สำหรับส่วนนั้น พร้อมเตือนเมื่อ feed มีข้อผิดพลาดหรือหมดเวลารอ นอกช่วงดังกล่าวจะไม่สมัคร realtime feed และซ่อน `⚫ N/A` ของ realtime Liquidity โดยยังแสดง TradingView 30-day estimate ตามปกติ

หาก Realtime request ได้ HTTP `401` (session หมดอายุ) จะ login ใหม่หนึ่งครั้งและลอง subscription ซ้ำหนึ่งครั้งตามแนวทาง Settrade; ข้อผิดพลาดอื่น เช่น HTTP `502` จะแสดง HTTP/API code และไม่ retry อัตโนมัติ Settrade ระบุว่า session อาจ reset ทุกวันช่วง 03:00–04:00 และ credentials ชุดเดียวกันไม่ควรถูก login พร้อมกันจากหลายโปรแกรม เพราะการ login ใหม่อาจทำให้ session ก่อนหน้าใช้ไม่ได้

เก็บ App ID/Secret ใน `.env` ที่ไม่ commit; ห้ามใส่ PIN หรือเลขบัญชี และระบบไม่เรียก account, portfolio, order หรือ trade endpoints. Settrade ระบุว่า Sandbox จำกัดการเข้าถึงจาก IP ในประเทศไทยตั้งแต่ 16 กันยายน 2026; การทดสอบจากพื้นที่อื่นอาจเชื่อมต่อไม่ได้

## ขอบเขตและข้อจำกัด

- ความสด ความถูกต้อง benchmark, timezone, ปฏิทินตลาด SET และการปรับ corporate actions ขึ้นกับวิธีสร้างข้อมูลใน workbook; ตัวตรวจไม่ได้รับรองเรื่องเหล่านี้
- การแสดงหุ้นเป็นการรายงานข้อมูลจาก snapshot ไม่ใช่คำแนะนำลงทุน
- `examples/SET-Summary.gs` เป็นตัวอย่างเสริมสำหรับสร้างแท็บสรุปใน Google Sheets; ไม่เกี่ยวข้องกับคำสั่ง `UPDATE`/`CANDIDATE`
