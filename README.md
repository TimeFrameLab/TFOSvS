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

รายงานใช้ read-only feeds เท่านั้น: มูลค่าซื้อขายสะสมวันนี้ (`InfoV3.total_value`), ราคา bid/ask ระดับแรก, spread และผลรวมปริมาณ order book bid/ask 10 ระดับ (`BidOfferV3`). แสดงตัวเลขดิบ ไม่จัดระดับสภาพคล่อง; ข้อมูลที่ขาดจะแสดง `N/A` พร้อมแจ้งข้อผิดพลาดหรือ timeout และจะไม่ใช้ cache แทน ไม่มีการใช้ PIN/เลขบัญชีหรือเรียก API บัญชี/คำสั่งซื้อขาย เก็บ credentials ไว้ใน `.env` และห้ามแชร์หรือ commit ค่าเหล่านี้

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
