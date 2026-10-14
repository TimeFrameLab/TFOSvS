# TimeFrame OS vS (SET)

## 📋 ภาพรวม

TimeFrame OS (vS) เป็นเครื่องมือสำหรับทำงานกับข้อมูลหุ้นไทยจาก Google Sheets:

- ดาวน์โหลด snapshot XLSX จาก Reference Sheet ที่กำหนดไว้
- ตรวจสอบโครงสร้างและข้อมูลพื้นฐานของ snapshot
- จัดกลุ่มรายงาน UPDATE และคัดหุ้น Candidate จาก signals ที่มีในชีต
- แสดงรายงานใน Terminal พร้อมลิงก์ Finnomena
- เก็บ snapshot ที่ดาวน์โหลดไว้ใน `downloads/` เพื่อให้ตรวจสอบข้อมูลชุดที่ใช้ได้

> **สถานะ: อยู่ระหว่างพัฒนา — ห้ามใช้วิเคราะห์หรือตัดสินใจซื้อขายหุ้นจริง**
>
> ระบบยังไม่คำนวณ MPTM จาก OHLCV หรือสร้างรายงาน Excel; Settrade market data เป็นตัวเลือก read-only และไม่มีการส่งคำสั่งซื้อขาย

## 🔔 การเริ่มต้นใช้งาน

```bash
git clone https://github.com/TimeFrameLab/TFOSvS.git
cd TFOSvS
cp .env.example .env
pip3 install -r requirements.txt
```

กำหนด URL ของ Google Sheets และชื่อแท็บใน `.env`:

```dotenv
SET_DATA_URL=https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit
SET_DATA_SHEET=All-SET-MTFS
```

ทุกครั้งที่รัน `UPDATE`, `UPDATE/<AKA>-<AKA>-...` หรือ `CANDIDATE` ระบบจะร้องขอ XLSX ใหม่จาก Google Sheets โดยส่งคำสั่งป้องกันการใช้ HTTP cache ก่อนตรวจและบันทึก snapshot ที่ `downloads/All-SET-MTFS.xlsx`; หากดาวน์โหลดไม่สำเร็จจะไม่ใช้ snapshot เก่าแทน URL ต้องอ่านได้โดยไม่ลงชื่อเข้าใช้ หาก workbook มีข้อมูลส่วนตัว ให้สร้างสำเนาที่ไม่มีข้อมูลดังกล่าวก่อนเปิดสิทธิ์อ่าน

### Liquidity จาก Settrade (ตัวเลือกเสริม)

เพื่อแสดง market data ให้เพิ่ม App ID และ App Secret ที่ได้รับอนุญาตลงใน `.env` ในเครื่อง:

```dotenv
SETTRADE_APP_ID=<APP_ID>
SETTRADE_APP_SECRET=<APP_SECRET>
SETTRADE_BROKER_ID=SANDBOX
SETTRADE_APP_CODE=SANDBOX
```

การทำงานจริงของระบบคือ: ทุกครั้งที่รัน `UPDATE` หรือ `CANDIDATE` จะอ่าน `.env` ก่อนดึง liquidity และ historical turnover จาก Settrade ผ่าน `load_config()` ใน [set_update.py](./set_update.py); หากค่า `SETTRADE_APP_ID` หรือ `SETTRADE_APP_SECRET` ไม่มี หรือ feed ไม่ตอบกลับ ระบบจะแสดง `⚫ N/A` พร้อมข้อความเตือนตามข้อเท็จจริง โดยไม่ใช้ cache หรือค่าเดียวที่คาดเดาแทน รายงานใช้ read-only feeds เท่านั้น: มูลค่าซื้อขายสะสมวันนี้ (`InfoV3.total_value`), ราคา bid/ask ระดับแรก, spread และผลรวมปริมาณ order book bid/ask 10 ระดับ (`BidOfferV3`). แสดงตัวเลขดิบ ไม่จัดระดับสภาพคล่อง; ข้อมูลที่ขาดจะแสดง `N/A` พร้อมแจ้งข้อผิดพลาดหรือ timeout และจะไม่ใช้ cache แทน สำหรับ `Avg Turnover 20D*` จะใช้ประมาณจาก `close × volume` เฉลี่ย 20 วัน และแจ้งว่าค่าดังกล่าวเป็นประมาณเท่านั้น ไม่มีการใช้ PIN/เลขบัญชีหรือเรียก API บัญชี/คำสั่งซื้อขาย เก็บ credentials ไว้ใน `.env` และห้ามแชร์หรือ commit ค่าเหล่านี้

> ตรวจสอบจริง: หาก `.env` มีค่า App ID/Secret อยู่แล้ว script จะนำไปใช้โดยอัตโนมัติในรันถัดไป; หากไม่มีค่า หรือ feed ไม่พร้อมใช้งาน จะเป็น `⚫ N/A` และไม่ได้ซ่อนไว้หรือลบโดยอัตโนมัติ

Settrade แจ้งว่า Sandbox จำกัดการเข้าถึงจาก IP ในประเทศไทยตั้งแต่ 16 กันยายน 2026; การเชื่อมต่อจากนอกประเทศไทยอาจใช้งานไม่ได้ รายงานยังคงทำงานและระบุ Liquidity ที่ไม่พร้อมใช้งานเมื่อไม่มี credentials หรือ feed

## 🧭 คำสั่งหลัก

| คำสั่ง | วิธีใช้ | ผลลัพธ์ |
|---|---|---|
| `START @README.md` | พิมพ์ในแชต | อ่าน README และทบทวน guideline ก่อนรอคำสั่ง |
| `UPDATE` | `./update.sh` | ดาวน์โหลด snapshot ตรวจข้อมูล และแสดงรายงานหุ้น |
| `UPDATE/<AKA>-<AKA>-...` | `./update.sh UPDATE/PTT-AOT-CPALL` | แสดงรายงานเฉพาะหุ้นที่ระบุ |
| `CANDIDATE` | `./candidate.sh` | คัดหุ้นตามเกณฑ์ Candidate 7 ข้อ |
| `REVIEW` | พิมพ์ในแชต | ทบทวน guideline อีกครั้ง |

## 📌 ข้อมูลสำคัญ

หลังได้รับคำสั่ง `START @README.md` ให้ยึดรูปแบบคำสั่งในเอกสารนี้อย่างเคร่งครัด: `UPDATE` ใช้ `./update.sh`, `UPDATE/<AKA>-<AKA>-...` ใช้ `./update.sh UPDATE/<AKA>-<AKA>-...` และ `CANDIDATE` ใช้ `./candidate.sh` ห้ามเปลี่ยนรูปแบบคำสั่งหรือแทนที่ด้วยวิธีอื่นโดยพลการ รายงานผลต้องรักษาลำดับข้อมูล รูปแบบตาราง ลิงก์ และข้อความเตือนตามที่กำหนดไว้ ห้ามคาดเดาผลลัพธ์หรืออ้างว่าดาวน์โหลด ตรวจสอบ หรือทำงานสำเร็จ หากไม่มีผลการทำงานและข้อมูลยืนยันจริง; เมื่อเกิดข้อผิดพลาดให้รายงานตามที่พบโดยไม่แสดงผลสำเร็จแทน

### ✅ มาตรฐานการแสดงผลสำหรับทุกคำสั่ง

ทุกครั้งที่เรียก `UPDATE`, `UPDATE/<AKA>-<AKA>-...` หรือ `CANDIDATE` ให้ใช้มาตรฐานการนำเสนอเดียวกัน แต่คงหัวข้อและคอลัมน์เฉพาะของแต่ละคำสั่งไว้ ไม่บังคับให้ `CANDIDATE` แสดงกลุ่มสถานะของ `UPDATE` หรือให้ `UPDATE` ใช้คอลัมน์ของ `CANDIDATE`

| ลำดับ | ส่วนรายงาน | มาตรฐานร่วม |
|---|---|---|
| 1 | หัวข้อและข้อมูลสรุป | แสดงเฉพาะหัวข้อ/metadata ที่คำสั่งนั้นกำหนด และใช้ค่าจาก snapshot ที่เพิ่งดาวน์โหลด |
| 2 | ผลลัพธ์ | แสดงหัวข้อ จำนวน และ Markdown table ตาม schema ของคำสั่งนั้น; คอลัมน์และลำดับต้องตรงตามตัวอย่างด้านล่าง |
| 3 | ชื่อหุ้น | ใช้ Markdown link Finnomena ตามรูปแบบ `https://www.finnomena.com/stock/<AKA>/advance` ทุกแถวที่มีชื่อหุ้น |
| 4 | หมายเหตุและคำเตือน | แสดงท้ายรายงานตามข้อมูลจริง ไม่ละคำเตือนที่เกี่ยวกับข้อมูลซึ่งนำมาแสดง |

เมื่อนำผลคำสั่งมาแสดงในแชต ให้แสดงรายงานฉบับเต็มเป็น Markdown ที่ render ได้จริง ไม่ครอบรายงานด้วย code fence, ไม่แปลงตารางเป็นข้อความคั่นช่องว่าง, ไม่ตัดแถว/คอลัมน์หรือคำเตือน และไม่เติมค่าที่ไม่มีใน output หากการรันผิดพลาด ให้แสดงข้อผิดพลาดแทนรายงานสำเร็จ

| รายการ | คำสั่งที่ต้องใช้ | ข้อบังคับด้านการแสดงผล | ห้ามทำ |
|---|---|---|---|
| `START @README.md` | พิมพ์คำสั่งในแชต | อ่าน README ก่อนทำงานและยึดคำแนะนำนี้อย่างเคร่งครัด | ไม่ใช้งานคำสั่งอื่นแทนหรือสรุปผิดจาก README |
| `UPDATE` | `./update.sh` | เริ่มรายงานด้วยสรุป `ADVANC` แล้วแสดงกลุ่ม `BUY CONFIRMED`, `EARLY/WATCH`, `PULLBACK ZONE`, `OVEREXTENDED`, `WAIT/RETEST` และคำเตือนท้ายรายงาน | ไม่แสดงกลุ่ม/metadata ของคำสั่งอื่นแทน; หยุดเมื่อข้อมูลสรุปที่บังคับขาด |
| `UPDATE/<AKA>-<AKA>-...` | `./update.sh UPDATE/PTT-AOT-CPALL` | แสดง metadata ของแต่ละ AKA ตามลำดับที่ขอ ตามด้วย `🔵 SPECIFIED STOCK — n รายการ`, ตารางหุ้นที่ระบุ และคำเตือนท้ายรายงาน | ไม่เพิ่มกลุ่ม UPDATE ปกติ; ไม่ละหุ้นหรือ metadata ที่ร้องขอ |
| `CANDIDATE` | `./candidate.sh` | แสดงหัวข้อ `ผลการค้นหา CANDIDATE (PRE-ENTRY-Like Pattern) — n หุ้น`, คำอธิบายเกณฑ์, ตาราง Candidate และคำเตือนท้ายรายงาน | ไม่เพิ่ม metadata `ADVANC` หรือกลุ่ม UPDATE; ไม่ปรับหัวข้อ คอลัมน์ หรือลำดับ |
| `REVIEW` | พิมพ์คำสั่งในแชต | ทบทวน guideline อีกครั้งเพื่อให้ตรงกับ Output Contract | ไม่ใช้ผลลัพธ์เก่า/HTTP cache แทนข้อมูลปัจจุบัน |
| การรายงานทุกกรณี | ทุกคำสั่ง | ยึด snapshot ล่าสุด; ใช้ Markdown table/link และคำเตือนตามจริง | ไม่อ้างว่าทำงานสำเร็จหากไม่มีข้อมูลยืนยัน หรือใช้ข้อมูลเก่าแทน |

## 🧩 แนวทางการแสดงผลแบบ TFOSvX สำหรับหุ้นไทย

แนวทางการแสดงผลนี้สืบทอดจากรูปแบบของ TFOSvX แต่ปรับให้ใช้กับข้อมูลหุ้นไทยและ snapshot ของ SET โดยมุ่งให้ทุกครั้งที่แสดงผลมีรูปแบบเดียวกัน เห็นลำดับชัดเจน และไม่อนุมานผลใด ๆ หากไม่มีข้อมูลยืนยันจริง

| ส่วนของผลลัพธ์ | รูปแบบบังคับ | ตัวอย่าง/สาระสำคัญ |
|---|---|---|
| ส่วนสรุปรวม | `AKA / LAST_CANDLE / UPDATED / GROUP` | ใช้รูปแบบ `AKA : ADVANC 🔔`, `LAST_CANDLE : ...`, `UPDATED : ...`, `GROUP : ...` อย่างเคร่งครัด |
| กลุ่มหลัก | `BUY CONFIRMED`, `EARLY/WATCH`, `PULLBACK ZONE`, `OVEREXTENDED`, `WAIT/RETEST` | จัดกลุ่มตาม snapshot ที่ดาวน์โหลดล่าสุดเท่านั้น; ไม่ใช้ข้อมูลเก่า/HTTP cache |
| หุ้นทุกแถว | Markdown link Finnomena | ทุกหุ้นในสรุปและ `OVEREXTENDED` ต้องเป็น `https://www.finnomena.com/stock/<AKA>/advance` |
| ตารางรายงาน | Markdown table | ใช้หัวคอลัมน์ตามที่กำหนดแน่นอน ไม่มีแทนคอลัมน์หรือสลับลำดับโดยพลการ |
| warning | ข้อความเตือนตามจริง | ระบุเมื่อข้อมูลค่า `value` ผิดปกติ, feed ไม่ครบ, credentials ขาด, หรือข้อมูลไม่พร้อมใช้งาน |

### 1) รูปแบบ `UPDATE`

```text
สรุปข้อมูลหุ้น
AKA         : ADVANC 🔔
LAST_CANDLE : 14/10/2026 16:00
UPDATED     : 14/10/2026 17:10
GROUP       : A

🟢 BUY CONFIRMED — 0 หุ้น
| หุ้น | GROUP | RSI(W) | RSI(D) | MACD_D | ราคา | Liquidity | Avg Turnover 20D* |
|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — |

🟡 EARLY/WATCH — 7 หุ้น (TOP 10)
| หุ้น | GROUP | RSI(W) | RSI(D) | MACD_D | ราคา | Liquidity | Avg Turnover 20D* |
|---|---|---|---|---|---|---|---|
| [SCC](https://www.finnomena.com/stock/SCC/advance) | A | 65.27 | 62.36 | 0.84941 | 277 | ... | ≈ ฿1,540,511,672.30 |

🟠 PULLBACK ZONE — 0 หุ้น (TOP 10)
| หุ้น | GROUP | RSI(W) | RSI(1H) | ราคา | VOL (x/4) | TREND (x/4) | CMB (x/4) | Liquidity | Avg Turnover 20D* |
|---|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — | — | — |

🔴 OVEREXTENDED — 3 หุ้น
| หุ้น | GROUP | Liquidity | Avg Turnover 20D* |
|---|---|---|---|
| [PLANB](https://www.finnomena.com/stock/PLANB/advance) | B | ... | ≈ ฿244,285,347.60 |

⚪ WAIT/RETEST — 106 หุ้น
```

หมายเหตุ:
- `LAST_CANDLE` และ `UPDATED` ต้องมีค่าในแถว `ADVANC`; หากขาดหรือว่างให้หยุดและรายงานข้อผิดพลาดแทนการคาดเดา
- `EARLY/WATCH` เรียงตาม `MACD_HIST_DELTA(W)` มากไปน้อย
- `PULLBACK ZONE` เรียงตาม Combined Score มากไปน้อย
- หุ้นที่ไม่พบหรือมี timestamp ว่างต้องแจ้งตามจริง และไม่ใช้ข้อมูลเก่าแทน

### 2) รูปแบบ `UPDATE/<AKA>-<AKA>-...`

```text
AKA         : PTT
LAST_CANDLE : 14/10/2026 16:00
UPDATED     : 14/10/2026 17:10
GROUP       : A

AKA         : SCC
LAST_CANDLE : 14/10/2026 16:00
UPDATED     : 14/10/2026 17:10
GROUP       : A

🔵 SPECIFIED STOCK — 2 รายการ
| AKA | GROUP | RSI(W) | RSI(1H) | ราคา | VOL (x/4) | TREND (x/4) | CMB (x/4) | Liquidity | Avg Turnover 20D* |
|---|---|---:|---:|---:|---|---|---|---|---:|
| [SCC](https://www.finnomena.com/stock/SCC/advance) | A | 65.27 | 73.26 | 277.0000 | 🟢🟢⚪🟢 (3/4) | 🟢🟢🟢🟢 (4/4) | ✅✅❌✅ (3/4) | ... | ≈ ฿1,540,511,672.30 |
| [PTT](https://www.finnomena.com/stock/PTT/advance) | A | 59.64 | 53.05 | 40.7500 | ... | ... | ... | ... | ≈ ฿4,214,308,537.22 |
```

ต้องยึดลำดับที่ร้องขอไว้ก่อน และแสดง `AKA`, `LAST_CANDLE`, `UPDATED`, `GROUP` สำหรับหุ้นแต่ละตัวตามลำดับนั้นโดยตรง

### 3) รูปแบบ `CANDIDATE`

```text
ผลการค้นหา CANDIDATE (PRE-ENTRY-Like Pattern) — 7 หุ้น
ผ่านเกณฑ์ CANDIDATE 7 ข้อ เรียงตาม MACD Delta (W) สูงสุด — รอ 1H Trigger ยืนยัน
| # | หุ้น | GROUP | ราคา (THB) | MACD Δ(W) | Entry Zone (4H) | 1H Trigger | Liquidity | Avg Turnover 20D* |
|---:|---|---|---:|---:|---|---|---|---:|
| 1 | [SCC](https://www.finnomena.com/stock/SCC/advance) | A | 277 | 0.84941 | 🔴 LH/LL | 🟡 WAIT | ... | ≈ ฿1,540,511,672.30 |
```

ลำดับคอลัมน์นี้ต้องเป็นไปตามที่กำหนด: `# | หุ้น | GROUP | ราคา (THB) | MACD Δ(W) | Entry Zone (4H) | 1H Trigger | Liquidity | Avg Turnover 20D*`

### ✅ ข้อกำหนดบังคับเรื่องการแสดงผล (Output Contract)

ก่อนแสดงผลทุกครั้ง ต้องยึดโครงสร้างร่วมและ schema เฉพาะคำสั่งให้ครบถ้วน:

- ใช้คำสั่งและรูปแบบสั่งงานตามที่ระบุในเอกสารนี้เท่านั้น; ห้ามเลี่ยงหรือเรียกแบบอื่นแทน
- `UPDATE` ปกติเริ่มด้วยบล็อกสรุป `AKA`, `LAST_CANDLE`, `UPDATED`, `GROUP` จากแถว `ADVANC`; หากคอลัมน์หรือค่า `LAST_CANDLE`/`UPDATED` ขาดหรือว่าง ต้องรายงานข้อผิดพลาดและหยุด ไม่คาดเดา
- `EARLY/WATCH` ต้องเรียงตาม `MACD_HIST_DELTA(W)` มากไปน้อย และ `PULLBACK ZONE` ต้องเรียงตาม Combined Score มากไปน้อย ตามที่กำหนดใน snapshot
- หุ้นทุกแถวและรายชื่อ `OVEREXTENDED` ต้องเป็น Markdown link ไปยัง `https://www.finnomena.com/stock/<AKA>/advance`
- `UPDATE/<AKA>-<AKA>-...` ต้องแสดงบล็อก `AKA`, `LAST_CANDLE`, `UPDATED`, `GROUP` สำหรับแต่ละหุ้นตามลำดับที่ร้องขอ และคงโครงสร้างตารางตามที่กำหนดไว้
- `CANDIDATE` ต้องแสดงหัวข้อ `ผลการค้นหา CANDIDATE (PRE-ENTRY-Like Pattern) — n หุ้น` และรักษาลำดับคอลัมน์ `# | หุ้น | GROUP | ราคา (THB) | MACD Δ(W) | Entry Zone (4H) | 1H Trigger | Liquidity | Avg Turnover 20D*`
- `CANDIDATE` ใช้ schema Candidate เท่านั้น; ไม่ต้องแสดงสรุป `ADVANC` หรือกลุ่มสถานะ UPDATE ส่วน `UPDATE/<AKA>-...` ใช้ schema SPECIFIED STOCK เท่านั้น; ไม่ต้องแสดงกลุ่ม UPDATE ปกติ
- รายงานที่แสดงในแชตต้องเป็น Markdown ที่ render ได้จริง โดยคงข้อมูลทุกแถว/คอลัมน์และคำเตือนตามผลคำสั่ง; ห้ามห่อด้วย code fence, ย่อ, สรุปแทนตาราง หรือสร้างค่าขึ้นเอง
- เมื่อไม่ได้รับข้อมูล/credentials/feed หรือดาวน์โหลดล้มเหลว ให้รายงานตามข้อเท็จจริงเท่านั้น ไม่อ้างว่าทำงานสำเร็จหรือใช้ข้อมูลเก่าแทน
- การรายงานต้องยึดตาม snapshot ล่าสุดที่เพิ่งดาวน์โหลดได้เท่านั้น; ห้ามใช้ HTTP cache หรือข้อมูลเก่าเพื่อบิดเบือนผลลัพธ์

## 📊 รูปแบบรายงานและเกณฑ์

`UPDATE` ปกติแสดงสรุปหุ้น `ADVANC` จากแถวของ AKA นี้ใน snapshot ก่อนรายงานกลุ่ม โดยใช้รูปแบบ:

```text
AKA         : ADVANC 🔔
LAST_CANDLE : <timestamp ของ candle ล่าสุด>
UPDATED     : <timestamp ที่ข้อมูลอัปเดตล่าสุด>
GROUP       : <GROUP>
```

คอลัมน์ `LAST_CANDLE` และ `UPDATED` ต้องมีอยู่และมีค่าในแถว `ADVANC`; หากขาด โปรแกรมจะแจ้งข้อผิดพลาดแทนการแสดงค่าที่คาดเดา `UPDATE` จากนั้นจัดกลุ่มผลเป็น `BUY CONFIRMED`, `EARLY/WATCH`, `PULLBACK ZONE`, `OVEREXTENDED` และ `WAIT/RETEST` ตามข้อมูลใน snapshot โดยเรียง `EARLY/WATCH` ตาม `MACD_HIST_DELTA(W)` และ `PULLBACK ZONE` ตาม Combined Score หุ้นแสดงเป็นลิงก์ `https://www.finnomena.com/stock/<AKA>/advance` และใช้คอลัมน์ `GROUP`

`UPDATE/<AKA>-<AKA>-...` แสดงบล็อก `AKA`, `LAST_CANDLE`, `UPDATED`, `GROUP` สำหรับแต่ละหุ้นตามลำดับที่ขอ แล้วแสดง `🔵 SPECIFIED STOCK — n รายการ` พร้อมตาราง `AKA | GROUP | RSI(W) | RSI(1H) | ราคา | VOL (x/4) | TREND (x/4) | CMB (x/4) | Liquidity | Avg Turnover 20D*`; แถวเรียงตามคะแนน CMB มากไปน้อย ส่วน AKA ที่ไม่พบหรือ timestamp ว่างจะแจ้งตามจริงและทำให้คำสั่งจบด้วย error status. ค่า Liquidity ยังคงเป็นตัวเลขดิบที่ได้รับจาก Settrade หรือ `⚫ N/A`; ไม่มีการแสดง HIGH/MEDIUM/LOW โดยไม่มีเกณฑ์ที่ยืนยันแล้ว ระบบไม่บันทึก Workbook ที่ดาวน์โหลดกลับไปยัง Google Sheets

`UPDATE` ปกติและ `UPDATE/<AKA>-...` จะประมวลผล signals และดึงข้อมูลก่อนแสดงรายงาน จากนั้นแสดง Liquidity ปัจจุบันและคอลัมน์ `Avg Turnover 20D*` ในตารางเดียวกัน ไม่มีตาราง refresh แยกด้านล่าง คำสั่ง UPDATE ปกติดึงเฉพาะหุ้นที่ปรากฏในตาราง (`BUY CONFIRMED`, `EARLY/WATCH` TOP 10, `PULLBACK ZONE` TOP 10 และ `OVEREXTENDED`); `WAIT/RETEST` แสดงจำนวนอย่างเดียวและไม่ดึงทั้ง Liquidity ปัจจุบันหรือข้อมูลย้อนหลัง การดึง feed ปัจจุบันทำทีละหุ้น (ไม่เกิน 2 subscriptions พร้อมกัน), ปิด feed ก่อนหุ้นถัดไป; ข้อมูลย้อนหลังใช้ daily candles จาก Settrade สำหรับ 20 วันซื้อขายที่มี volume ก่อนวันนี้ ภายในงบเวลาประมวลผลรวม 120 วินาที หากข้อมูลย้อนหลังไม่ครบจะแสดง `⚫ N/A`

`Avg Turnover 20D*` เป็นค่าประมาณจาก `close × volume` เฉลี่ย 20 วัน ไม่ใช่มูลค่าซื้อขายจริง เนื่องจากการทดสอบ UAT พบว่าฟิลด์ daily `value` เป็นศูนย์แม้มี volume; ระบบจะแจ้งความผิดปกติของฟิลด์นี้และไม่ใช้แทนค่าประมาณโดยไม่เปิดเผย ข้อมูลนี้ยังไม่ใช้จัดระดับ `HIGH/MEDIUM/LOW` และยังต้องยืนยันความหมาย/คุณภาพฟิลด์กับผู้ให้บริการก่อนใช้จริง

`CANDIDATE` ผ่านเมื่อครบทุกเงื่อนไข:

1. `TREND(W) = UP`
2. `TREND(D) = UP`
3. `RSI(W) > 50`
4. `MACD_HIST_DELTA(W) > 0`
5. `RSI(D) < 70`
6. `EMA9(W) > EMA21(W)`
7. `SIGNAL_VOLUME` เป็น `BUY` อย่างน้อยหนึ่ง timeframe ใน W/D/4H/1H

รายงานแสดงจำนวนผู้ผ่านทั้งหมดและไม่เกิน 20 แถว เรียงตาม `MACD_HIST_DELTA(W)` จากมากไปน้อย พร้อม `GROUP`, ราคา, `ENTRY_ZONE(4H)`, `ENTRY_TRIGGER(1H)`, Liquidity และ `Avg Turnover 20D*`; ดึงข้อมูลเพิ่มเฉพาะผู้ผ่านที่แสดงใน 20 แถวแรก

## 💧 แหล่งข้อมูล Liquidity

หากไม่มี credentials หรือ feed ใช้งานไม่ได้ ตารางแสดง `⚫ N/A` ซึ่งหมายถึงไม่มีข้อมูลยืนยัน ไม่ใช่ระดับสภาพคล่องต่ำ เมื่อตั้งค่า Settrade จะรายงานตัวเลขดิบจากแหล่งดังกล่าว แหล่งข้อมูลอื่นที่นำมาใช้ได้มี:

1. **ข้อมูลจาก SET ผ่านบริการข้อมูลที่ได้รับอนุญาต** — ตัวเลือกแนะนำสำหรับความน่าเชื่อถือและสิทธิ์การใช้งาน ควรตรวจสอบว่าบริการที่เลือกมีข้อมูลมูลค่าซื้อขายย้อนหลังและ/หรือราคาเสนอซื้อขายกับปริมาณคงเหลือ รวมทั้งเงื่อนไขการนำข้อมูลมาใช้
2. **ผู้ให้บริการข้อมูลตลาดหรือ API ของโบรกเกอร์** — ใช้ได้เมื่อผู้ให้บริการรองรับหลักทรัพย์ SET, มีข้อมูลและความถี่ที่ต้องการ และอนุญาตให้ใช้ข้อมูลในรายงานนี้
3. **คอลัมน์ใน Reference Sheet** — เหมาะกับ workflow ปัจจุบัน หากเพิ่มข้อมูลจากแหล่งที่ระบุชัดเจน เช่น มูลค่าซื้อขายเฉลี่ยย้อนหลังและเวลาอ้างอิง แล้วส่งต่อมาใน snapshot

ระบบปัจจุบันไม่จัดระดับ HIGH/MEDIUM/LOW และไม่ดึงค่าเก่ามาทดแทนข้อมูลที่ขาด ห้ามอนุมาน Liquidity จาก `SIGNAL_VOLUME` หรือใช้ข้อมูลจากหน้าแสดงกราฟแทนข้อมูลตลาดที่ตรวจสอบแหล่งที่มาได้

## 🛡️ ขอบเขตและข้อควรระวัง

- คอลัมน์หลักที่ใช้ ได้แก่ `AKA`, `GROUP`, `PRICE`, `ACTION`, `TREND`, `RSI`, `MACD_HIST_DELTA(W)` และ `RELATIVE_STRENGTH` ของ timeframe ที่กำหนด รวมถึง `EMA9(W)`, `EMA21(W)`, `SIGNAL_VOLUME`, `ENTRY_ZONE(4H)` และ `ENTRY_TRIGGER(1H)` สำหรับรายงาน Candidate
- ตัวตรวจเช็กรูปแบบและความครบถ้วนของข้อมูลพื้นฐาน ไม่รับรองความสด benchmark, timezone, ปฏิทินตลาด, corporate actions, tick size หรือ board lot
- ข้อมูลที่แสดงเป็น signals จาก snapshot และ market data read-only ไม่ใช่คำแนะนำซื้อขาย; รายงานไม่แก้ไข workbook ต้นทาง
- เก็บ `.env` ไว้ในเครื่อง และอย่าเผยแพร่ workbook ที่มีข้อมูลส่วนตัว

คู่มือการตั้งค่าเพิ่มเติมอยู่ที่ [GOOGLE-SHEETS-SETUP.md](./GOOGLE-SHEETS-SETUP.md) และแนวทางการทำงานอยู่ที่ [TimeFrame-OS-guidelines-and-model-vS.md](./TimeFrame-OS-guidelines-and-model-vS.md).
