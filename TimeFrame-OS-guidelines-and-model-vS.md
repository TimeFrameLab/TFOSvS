# TimeFrame OS vS — แนวทางสำหรับตลาดหุ้นไทย (SET)

## สถานะและขอบเขต

TFOSvS อยู่ระหว่างพัฒนาและยังไม่ใช่ระบบแนะนำการลงทุนหรือส่งคำสั่งซื้อขาย `update.sh` และ `candidate.sh` เรียก `tfos.sh` เป็น Bash entrypoint; AWK จัดกลุ่ม MPTM จาก signals ใน snapshot ส่วน inline Python ใช้เฉพาะอ่าน/เขียน XLSX และเรียก Settrade API ไม่มีไฟล์ `*.py` หรือ `report.awk` ถาวรใน workflow นี้

ยังไม่มีการดึง OHLCV จาก API ตลาดหรือคำสั่งซื้อขาย; Settrade (ถ้าตั้งค่า) ใช้เฉพาะ public market-data feeds ไม่เรียก API บัญชีหรือคำสั่ง

## การตั้งค่า

สร้าง `.env` จาก `.env.example` แล้วกำหนด URL ของ Google Sheets และชื่อแท็บ:

```dotenv
SET_DATA_URL=https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit
SET_DATA_SHEET=All-SET-MTFS
```

เก็บ `.env` ไว้ในเครื่องเท่านั้น ไฟล์ XLSX ที่ดาวน์โหลดถูกเก็บใน `downloads/` และไม่ถูกเพิ่มใน Git การดาวน์โหลดต้องใช้ชีตที่อ่านได้โดยไม่ลงชื่อเข้าใช้; อย่าเปิดเผย workbook ที่มีข้อมูลส่วนตัว ใช้สำเนาที่ไม่มีข้อมูลส่วนตัว ดูวิธีใช้ที่ [คู่มือคำสั่ง](./GOOGLE-SHEETS-SETUP.md)

การดึง Liquidity จาก Settrade เป็นตัวเลือกเสริม ให้กำหนด `SETTRADE_APP_ID`, `SETTRADE_APP_SECRET`, `SETTRADE_BROKER_ID` และ `SETTRADE_APP_CODE` ใน `.env` โดยใช้ App credentials ที่ได้รับอนุญาตเท่านั้น ห้ามบันทึก PIN หรือเลขบัญชี ระบบไม่เรียก endpoint ของ account, portfolio, order หรือ trade หากไม่มี credentials หรือ feed ใช้งานไม่ได้ ช่อง Liquidity จะแสดง `⚫ N/A` และรายงานสาเหตุ

## รูปแบบข้อมูล

แท็บ `All-SET-MTFS` ต้องมี `AKA`, `GROUP`, `PRICE`, `ACTION`, TREND/RSI และ Relative Strength ของ W/D/4H/1H, `MACD_HIST_DELTA(W)` และคอลัมน์สำหรับ Candidate ตาม [คู่มือคำสั่ง](./GOOGLE-SHEETS-SETUP.md) ใช้ `GROUP` จากชีตแทน `TIER` และไม่ตีความ/แปลงค่าของ `GROUP` เอง

## ตรวจ signals ที่มีอยู่

คำสั่ง `UPDATE` ดึง workbook ใหม่ทุกครั้งและเก็บ snapshot ไว้ที่ `downloads/All-SET-MTFS.xlsx`:

```bash
./update.sh
./update.sh UPDATE/PTT-AOT-CPALL
```

โปรแกรมตรวจ:

- พบแท็บและคอลัมน์ที่จำเป็น
- `AKA` มีรูปแบบที่ยอมรับได้และไม่ซ้ำกัน
- `GROUP`, trend และ relative-strength fields ไม่ว่าง
- `PRICE` เป็นตัวเลขที่มากกว่า 0; ค่า RSI เป็นตัวเลขระหว่าง 0 ถึง 100; ค่า MACD delta เป็นตัวเลข finite

เมื่อผ่านการตรวจ ตัวตรวจจะแสดงตารางหุ้นตาม `GROUP`, ราคา, TREND/RSI, ACTION และลิงก์ Finnomena หากมีข้อผิดพลาดจะรายงานตำแหน่งแถวและหยุด

## UPDATE และ CANDIDATE

- `UPDATE` ใช้ `./update.sh`; `UPDATE/<AKA>-<AKA>-...` ส่งเป็น argument เช่น `./update.sh UPDATE/PTT-AOT-CPALL`
- ทุกครั้งที่เรียก `UPDATE`, `UPDATE/<AKA>-...` หรือ `CANDIDATE` จะร้องขอ XLSX ใหม่จาก `SET_DATA_URL` พร้อมคำสั่งป้องกันการใช้ HTTP cache แล้วอ่าน snapshot ที่เพิ่งดาวน์โหลดเท่านั้น; หากดาวน์โหลดล้มเหลวจะไม่ใช้ไฟล์เก่าแทน
- `CANDIDATE` ใช้ `./candidate.sh`; เลือกหุ้นที่ผ่านครบทุกเงื่อนไข:
  1. `TREND(W) = UP`
  2. `TREND(D) = UP`
  3. `RSI(W) > 50`
  4. `MACD_HIST_DELTA(W) > 0`
  5. `RSI(D) < 70`
  6. `EMA9(W) > EMA21(W)`
  7. `SIGNAL_VOLUME` เป็น `BUY` อย่างน้อยหนึ่ง timeframe ใน W/D/4H/1H
- คำสั่งแสดงผลใน Terminal และสร้าง/อัปเดตรายงาน `downloads/All-SET-MTFS_output.xlsx`; ไม่แก้ workbook ต้นทาง ไม่คำนวณ OHLCV/signals ใหม่ และไม่ส่งคำสั่งซื้อขาย

### รูปแบบรายงาน

รายงาน Excel มีสามชีท: `Latest Snapshot` สำหรับผลล่าสุดและสถานะ/คำแนะนำพร้อม TREND(W)/TREND(D), `Master Signal Log` สำหรับประวัติแบบ append-only และ `REF.` สำหรับลิงก์ต้นทาง หาก schema ของประวัติเดิมไม่ตรง ระบบต้องหยุด ไม่เขียนทับประวัติ

สถานะ MPTM ที่แสดง: 🟢 `BUY CONFIRMED` เมื่อผ่านเกณฑ์ MPTM และ 1H Trigger ยืนยัน; 🟡 `EARLY/WATCH` เมื่อผ่าน MPTM แต่รอ 1H Trigger; 🟠 `PULLBACK ZONE` เมื่อ W/D/4H/1H เป็น UP แต่ RSI(1H) < 50; 🔴 `OVEREXTENDED` เมื่อ RSI(D) ≥ 70; ⚪ `WAIT/RETEST` เมื่อโครงสร้างยังไม่พร้อม โดยแสดงเฉพาะจำนวนหุ้น

- ใช้มาตรฐานการนำเสนอร่วมกันทุกคำสั่ง: หัวข้อ/metadata ที่คำสั่งนั้นกำหนด → ผลลัพธ์ใน Markdown table ตาม schema ของคำสั่ง → คำเตือนตามจริงท้ายรายงาน คงหัวข้อ ลำดับคอลัมน์ ลำดับแถว และเนื้อหาจาก stdout ให้ครบถ้วน
- เมื่อแสดงผลในแชต ให้ render ตารางเป็น Markdown จริง ไม่ครอบรายงานด้วย code fence ไม่ตัดทอน/สรุปแทนตาราง และไม่เติมค่าที่ไม่มีในผลการรัน
- schema เป็นไปตามคำสั่ง ไม่ใช่การบังคับให้ทุกคำสั่งใช้เนื้อหาเหมือนกัน:

  | คำสั่ง | ส่วนหัว | ตารางผลลัพธ์ | ส่วนท้าย |
  |---|---|---|---|
  | `UPDATE` | สรุปจากแถว `ADVANC`: `AKA`, `LAST_CANDLE`, `UPDATED`, `GROUP` | ห้ากลุ่มสถานะตามตัวอย่างใน README; `WAIT/RETEST` แสดงจำนวนอย่างเดียว | คำเตือนตามจริง |
  | `UPDATE/<AKA>-<AKA>-...` | metadata `AKA`, `LAST_CANDLE`, `UPDATED`, `GROUP` สำหรับทุกหุ้นตามลำดับที่ร้องขอ | `🔵 SPECIFIED STOCK` พร้อมคอลัมน์ `AKA | GROUP | RSI(W) | RSI(1H) | ราคา | VOL (x/4) | TREND (x/4) | CMB (x/4) | Liquidity | Avg Turnover Estimate*` | แจ้งหุ้นที่ไม่พบ/metadata ไม่ครบและคำเตือนตามจริง |
  | `CANDIDATE` | หัวข้อ `ผลการค้นหา CANDIDATE (PRE-ENTRY-Like Pattern) — n หุ้น` และข้อความเกณฑ์ | `# | หุ้น | GROUP | ราคา (THB) | MACD Δ(W) | Entry Zone (4H) | 1H Trigger | Liquidity | Avg Turnover Estimate*` | คำเตือนตามจริง |

- สำหรับ `UPDATE` ปกติ ต้องมีคอลัมน์ `LAST_CANDLE`, `UPDATED` และค่าทั้งสองในแถว `ADVANC`; หากไม่ครบให้รายงานข้อผิดพลาด ไม่คาดเดาหรือแสดงผลสำเร็จแทน
- `CANDIDATE` ไม่แสดงสรุป `ADVANC` หรือกลุ่มสถานะ UPDATE; `UPDATE/<AKA>-...` ไม่แสดงกลุ่ม UPDATE ปกติ ห้ามเพิ่มส่วนที่คำสั่งนั้นไม่ได้สร้าง
- หุ้นที่มีชื่อในตารางต้องเป็น Markdown link ไปยัง Finnomena ตามรูปแบบ `https://www.finnomena.com/stock/<AKA>/advance`

- `Output Contract` (ข้อกำหนดบังคับเรื่องการแสดงผล): ก่อนแสดงผลทุกครั้ง ต้องยึดเงื่อนไขต่อไปนี้ให้ครบถ้วน
  - ใช้คำสั่งและรูปแบบงานที่กำหนดเท่านั้น; ห้ามเลี่ยงหรือเรียกแบบอื่นแทน
  - `UPDATE` ปกติต้องเริ่มด้วยบล็อก `AKA / LAST_CANDLE / UPDATED / GROUP` ตามรูปแบบแน่นอน หากคอลัมน์หรือค่า `LAST_CANDLE` หรือ `UPDATED` ในแถว `ADVANC` ขาดหรือว่าง ต้องรายงานข้อผิดพลาดและหยุด ไม่คาดเดาหรือสรุปว่าดี/สำเร็จ
  - `EARLY/WATCH` ต้องเรียงตาม `MACD_HIST_DELTA(W)` มากไปน้อย และ `PULLBACK ZONE` ต้องเรียงตาม Combined Score มากไปน้อย ตาม snapshot
  - ตารางทุกคำสั่งต้องเป็น Markdown table; หุ้นทุกแถวต้องเป็น Markdown link ไปยัง Finnomena ตามรูปแบบ `https://www.finnomena.com/stock/<AKA>/advance`
  - `UPDATE/<AKA>-<AKA>-...` ต้องแสดงบล็อก `AKA`, `LAST_CANDLE`, `UPDATED`, `GROUP` ตามลำดับที่ร้องขอ และคงโครงสร้างตารางตามที่กำหนดไว้
  - `CANDIDATE` ต้องแสดงหัวข้อ `ผลการค้นหา CANDIDATE (PRE-ENTRY-Like Pattern) — n หุ้น` และรักษาลำดับคอลัมน์ `# | หุ้น | GROUP | ราคา (THB) | MACD Δ(W) | Entry Zone (4H) | 1H Trigger | Liquidity | Avg Turnover Estimate*`
  - ห้ามเพิ่ม metadata `ADVANC` หรือกลุ่ม UPDATE ลงใน `CANDIDATE`; ห้ามเพิ่มกลุ่ม UPDATE ลงใน `UPDATE/<AKA>-...`
  - เมื่อรายงานผลในแชต ต้อง render Markdown ฉบับเต็ม ไม่ใช้ code fence, ไม่ย่อหรือแทนตารางด้วยข้อความ และไม่สร้างค่าขึ้นเอง
  - หากข้อมูล/credentials/feed ไม่พร้อมหรือดาวน์โหลดล้มเหลว ต้องรายงานตามข้อเท็จจริงเท่านั้น ไม่อ้างว่าแสดงผลสำเร็จหรือใช้ข้อมูลเก่าแทน
  - การรายงานต้องยึด snapshot ล่าสุดที่เพิ่งดาวน์โหลดได้เท่านั้น ห้ามใช้ HTTP cache หรือข้อมูลเก่าเพื่อบิดเบือนผลลัพธ์
- หลังสรุป `UPDATE` แสดงกลุ่ม `🟢 BUY CONFIRMED`, `🟡 EARLY/WATCH`, `🟠 PULLBACK ZONE`, `🔴 OVEREXTENDED` และ `⚪ WAIT/RETEST` ตาม signals ใน snapshot; `EARLY/WATCH` เรียงตาม `MACD_HIST_DELTA(W)` มากไปน้อย และ `PULLBACK ZONE` เรียงตาม Combined Score มากไปน้อย
- ตารางใช้ `GROUP` แทน `TIER`; หุ้นทุกแถวและรายชื่อ OVEREXTENDED เป็น Markdown link ไปยัง Finnomena ตามรูปแบบ `https://www.finnomena.com/stock/<AKA>/advance`
- `CANDIDATE` แสดงหัวข้อ `ผลการค้นหา CANDIDATE (PRE-ENTRY-Like Pattern) — n หุ้น` ตารางแสดงไม่เกิน 20 รายการ เรียง `MACD_HIST_DELTA(W)` มากไปน้อย และคงลำดับคอลัมน์ `# | หุ้น | GROUP | ราคา (THB) | MACD Δ(W) | Entry Zone (4H) | 1H Trigger | Liquidity | Avg Turnover Estimate*`; ดึง Liquidity และข้อมูลย้อนหลังเฉพาะหุ้นที่แสดงใน TOP 20
- เมื่อมี Settrade credentials ระบบสมัคร feed read-only สำหรับมูลค่าซื้อขายสะสมวันนี้ (`InfoV3.total_value`) และ bid/ask 10 ระดับ (`BidOfferV3`); แสดง turnover, ราคา bid/ask ระดับแรก, spread และผลรวมปริมาณ bid/ask 10 ระดับเป็นตัวเลขดิบเท่านั้น ไม่จัดระดับ HIGH/MEDIUM/LOW
- ระหว่างวันจันทร์–ศุกร์ เวลา 10:00–12:30 และ 14:30–16:30 น. ตามเวลาไทย หากไม่มี credentials, feed ไม่ตอบกลับ หรือข้อมูลบางส่วนไม่ครบ ระบบแสดง `⚫ N/A` เฉพาะค่าที่ไม่มีและเตือนสาเหตุ; นอกช่วงนี้ไม่สมัคร realtime feed และไม่แสดง `⚫ N/A` สำหรับ realtime Liquidity; ไม่ใช้ snapshot หรือ cache เก่ามาแทน การตรวจเวลาไม่พิจารณาปฏิทินวันหยุด SET
- `UPDATE` ปกติประมวลผล signals และดึง Liquidity กับข้อมูล turnover ย้อนหลังของหมวดที่แสดงให้เสร็จก่อนพิมพ์รายงาน แล้วแสดงค่าทั้งสองพร้อม signals ในตารางหมวดเดียวกัน ไม่แสดงตาราง refresh แยกด้านล่าง ดึงเฉพาะ BUY CONFIRMED, EARLY/WATCH สูงสุด 10, PULLBACK ZONE สูงสุด 10 และ OVEREXTENDED; WAIT/RETEST แสดงเพียงจำนวน จึงไม่ดึง Liquidity หรือ Avg Turnover Estimate*
- Liquidity ประมวลผลทีละหุ้น โดยเปิดไม่เกินสอง feed subscriptions พร้อมกันและปิดก่อนหุ้นถัดไป จำกัดเวลารวมของคำขอแต่ละครั้ง 120 วินาที และแสดงสรุปข้อมูลครบ/ข้อผิดพลาด เพื่อลดปัญหา subscription limit โดยไม่อ้างว่าได้ข้อมูลสำหรับหุ้นที่ไม่ได้ร้องขอ; เมื่อหมดเวลา หุ้นที่เหลือจะแสดงเป็น `N/A` พร้อมคำเตือน
- `UPDATE` ใช้ TradingView Thailand scanner field `AvgValue.Traded_30d` เป็นแหล่ง estimate หลักโดยตรง ไม่ต้องใช้ CSV; เป็น rolling average 30 วัน ไม่ใช่ค่า 20 วัน และแสดงเป็น `TradingView Screener 30D avg` หาก TradingView ไม่มีค่าหรือ endpoint ใช้ไม่ได้จึงเตือนและลองใช้ Settrade historical estimate ถ้ามี มิฉะนั้น `⚫ N/A`. Estimate ไม่ใช่มูลค่าซื้อขายจริงและไม่ใช้แทน realtime Bid–Ask/turnover วันนี้
- `UPDATE/<AKA>-<AKA>-...` แสดงข้อมูล `AKA`, `LAST_CANDLE`, `UPDATED`, `GROUP` แยกทีละหุ้นตามลำดับที่ขอ แล้วตามด้วย `🔵 SPECIFIED STOCK — n รายการ` และตารางคอลัมน์ `AKA | GROUP | RSI(W) | RSI(1H) | ราคา | VOL (x/4) | TREND (x/4) | CMB (x/4) | Liquidity | Avg Turnover Estimate*`; เรียงตารางตาม CMB score มากไปน้อย
- AKA ที่ไม่พบหรือ timestamp ว่างต้องแจ้งตามจริงและคืน error status; คำสั่งแสดงผลจาก snapshot และไม่แก้หรือบันทึก Workbook ต้นทาง

### แหล่งข้อมูล Liquidity

แหล่ง Realtime Bid–Ask/turnover วันนี้ใช้ Settrade read-only feeds ในวันจันทร์–ศุกร์ เวลา 10:00–12:30 และ 14:30–16:30 น. ตามเวลาไทย; นอกช่วงนี้ไม่สมัคร feed และไม่แสดง `⚫ N/A` สำหรับ realtime Liquidity (ไม่มีการตรวจวันหยุด SET). ในช่วงตลาดเปิด หาก feed ใช้ไม่ได้ให้แสดง `⚫ N/A` โดยไม่แทนด้วยค่า estimate ส่วน historical turnover estimate ใช้ TradingView Thailand scanner field `AvgValue.Traded_30d` (rolling average 30 วัน) โดยตรง เมื่อไม่มีข้อมูลจาก TradingView จึงลอง Settrade historical estimate; ถ้าไม่มีทั้งสองแหล่งให้แสดง `⚫ N/A` พร้อมคำเตือน แสดงแหล่ง estimate ชัดเจนและห้ามเรียกว่า 20-day average

ยังไม่มีการกำหนด threshold การจัดระดับ จึงห้ามจัดประเภท Liquidity; ห้ามอนุมานจาก `SIGNAL_VOLUME` หรือแสดงว่าเป็นผลตรวจจริงจนกว่าจะได้ข้อมูลจากแหล่งที่เลือกและตรวจยืนยันได้

ข้อมูล turnover เป็นมูลค่าซื้อขายสะสมของวันปัจจุบัน ไม่ใช่ค่าเฉลี่ยย้อนหลัง; order-book depth เป็นผลรวมปริมาณจากสิบระดับของ feed ณ เวลาที่ได้รับ ส่วน spread คำนวณจาก ask/bid ระดับแรก และอาจไม่มีค่าระหว่าง auction หรือเมื่อราคาเสนอซื้อ/ขายเป็นศูนย์

Settrade ระบุว่า Sandbox จำกัดการเข้าถึงจาก IP ในประเทศไทยตั้งแต่ 16 กันยายน 2026; สภาพแวดล้อมที่อยู่นอกประเทศอาจเชื่อมต่อ Sandbox ไม่ได้

## ข้อมูลสำคัญ

หลังได้รับคำสั่ง `START @README.md` ให้ยึดรูปแบบคำสั่งในเอกสารนี้อย่างเคร่งครัด: `UPDATE` ใช้ `./update.sh`, `UPDATE/<AKA>-<AKA>-...` ใช้ `./update.sh UPDATE/<AKA>-<AKA>-...` และ `CANDIDATE` ใช้ `./candidate.sh` ห้ามเปลี่ยนรูปแบบคำสั่งหรือแทนที่ด้วยวิธีอื่นโดยพลการ รายงานผลต้องรักษาลำดับข้อมูล รูปแบบตาราง ลิงก์ และข้อความเตือนตามที่กำหนดไว้ ห้ามคาดเดาผลลัพธ์หรืออ้างว่าดาวน์โหลด ตรวจสอบ หรือทำงานสำเร็จ หากไม่มีผลการทำงานและข้อมูลยืนยันจริง; เมื่อเกิดข้อผิดพลาดให้รายงานตามที่พบโดยไม่แสดงผลสำเร็จแทน

## ข้อจำกัดที่ยังไม่ได้ยืนยัน

ข้อมูล/โค้ดปัจจุบันยังไม่ยืนยันสิ่งต่อไปนี้ จึงห้ามอ้างว่าระบบได้ตรวจหรือจัดการแล้ว:

- แหล่งที่มา/สิทธิ์ใช้งานและความสดของ indicators ใน workbook
- timestamp/timezone และวิธีคำนวณ timeframe ให้ตรง session ตลาด SET
- การปรับ indicators สำหรับ corporate actions และ symbol changes
- benchmark และความหมายของ `RELATIVE_STRENGTH`
- ปฏิทินและ session ซื้อขายของ SET รวมถึงวันหยุดหรือการหยุดซื้อขาย
- corporate actions, การเปลี่ยน ticker และการปรับข้อมูลย้อนหลัง
- tick size, board lot, trading unit และข้อจำกัดของหลักทรัพย์แต่ละประเภท
- การคำนวณ MPTM จาก OHLCV, การจัดสถานะ/คำแนะนำ และการเชื่อมต่อโบรกเกอร์

การแสดงค่าจากชีตไม่ได้รับรองความถูกต้อง ความครบถ้วน หรือความทันเวลาของข้อมูล และไม่ใช่คำแนะนำซื้อขาย

## ขอบเขตความปลอดภัย

- `UPDATE`/`CANDIDATE` ดาวน์โหลด snapshot จาก Google Sheets และเรียก Settrade เฉพาะหุ้นที่แสดงเพื่อดึง Liquidity/ข้อมูลย้อนหลัง; ใช้ read-only market data เท่านั้น ไม่มี API บัญชีหรือคำสั่งซื้อขาย
- ก่อนพัฒนาการวิเคราะห์หรือซื้อขายจริง ต้องยืนยันแหล่งข้อมูล/สิทธิ์ใช้งาน freshness, benchmark, ปฏิทินตลาด, corporate actions และกฎหลักทรัพย์ พร้อมทดสอบกับข้อมูลที่ตรวจสอบย้อนกลับได้
