/**
 * ==============================================================================
 * SUBH PAPER COMPANY - ENTERPRISE GOOGLE DRIVE CLOUD BACKEND ENGINE
 * ==============================================================================
 * Architecture: Google Apps Script Web App + Google Drive JSON Storage
 * Cost: ₹0 / 100% Free Forever (Standard Gmail Account)
 * Access: Anywhere across 4G, 5G, Wi-Fi, Office, Home & Mobile Devices
 * Security: Anti-Delete Protection, ScriptLock Concurrency, Auto-Version History
 * ==============================================================================
 */

const FOLDER_NAME = "Subh_Paper_Company_Database";
const FILE_NAME = "Order_Tracking_Master.json";

/**
 * 1. GET Request Handler (Fetch Latest Database)
 * Called by Desktop and Mobile screens to retrieve live data or check versions
 */
function doGet(e) {
  try {
    const data = getOrCreateMasterFile();
    const output = {
      status: "success",
      version: data.timestamp || new Date().toISOString(),
      skus_count: data.skus ? data.skus.length : 0,
      database: data
    };
    return ContentService.createTextOutput(JSON.stringify(output))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * 2. POST Request Handler (Save Database Updates)
 * Uses Google LockService to ensure multi-user safety (No two users overwrite each other)
 */
function doPost(e) {
  // Concurrency Lock: If 5 users save at the exact same second, queue them safely
  const lock = LockService.getScriptLock();
  try {
    // Wait up to 30 seconds for lock to acquire
    lock.waitLock(30000);
  } catch (lockErr) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: "Server busy. Another user is currently saving data. Please retry in a few seconds."
    })).setMimeType(ContentService.MimeType.JSON);
  }

  try {
    if (!e || !e.postData || !e.postData.contents) {
      throw new Error("Empty request body received.");
    }

    const payload = JSON.parse(e.postData.contents);

    // ANTI-DELETE SECURITY GUARD:
    // Reject any payload that attempts to wipe out all SKUs or corrupt the schema
    if (!payload || !payload.skus || !Array.isArray(payload.skus) || payload.skus.length === 0) {
      throw new Error("Security Guard: Blank or corrupt database write rejected. Minimum 1 SKU required.");
    }

    // Set authoritative server timestamp
    payload.timestamp = new Date().toISOString();

    // Write directly to Owner's Google Drive file
    saveToDriveFile(payload);

    return ContentService.createTextOutput(JSON.stringify({
      status: "success",
      version: payload.timestamp,
      skus_count: payload.skus.length,
      message: "Successfully synchronized directly to Owner's Google Drive!"
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  } finally {
    // Always release lock
    lock.releaseLock();
  }
}

/**
 * Helper: Find or Create Google Drive Folder & Master JSON File
 */
function getOrCreateMasterFolder() {
  const folders = DriveApp.getFoldersByName(FOLDER_NAME);
  if (folders.hasNext()) {
    return folders.next();
  }
  return DriveApp.createFolder(FOLDER_NAME);
}

function getOrCreateMasterFile() {
  const folder = getOrCreateMasterFolder();
  const files = folder.getFilesByName(FILE_NAME);
  if (files.hasNext()) {
    const file = files.next();
    const content = file.getBlob().getDataAsString("UTF-8");
    return JSON.parse(content);
  }

  // Initial Seed with existing live database
  const initialData = {
  "system": "Subh Paper Company Order Tracking Enterprise Database",
  "version": "6.0",
  "timestamp": "2026-10-18T10:15:00.000Z",
  "activeVendor": "all",
  "skus": [
    {
      "vendor": "Camlin",
      "barcode": "1152203052",
      "description": "A4 SC Design SL 52Pg Longbook",
      "orderQty": 15000,
      "oldStock": 0,
      "production": 26712,
      "despatched": 26712,
      "size": "A4 SL DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 52,
      "reelSize": 90.0,
      "cut": 43.0,
      "gsm": 57.0,
      "bookWt": 0.09559,
      "inner": 12,
      "caseQty": 120,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1152201052",
      "description": "A4 SC Design UR 52Pg Longbook",
      "orderQty": 15000,
      "oldStock": 0,
      "production": 10000,
      "despatched": 10000,
      "size": "A4 UR DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 52,
      "reelSize": 90.0,
      "cut": 43.0,
      "gsm": 57.0,
      "bookWt": 0.09559,
      "inner": 12,
      "caseQty": 120,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1152205100",
      "description": "A4 SC Design 4L 100Pg Longbook",
      "orderQty": 15000,
      "oldStock": 0,
      "production": 11424,
      "despatched": 11376,
      "size": "A4 4L DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 100,
      "reelSize": 90.0,
      "cut": 43.0,
      "gsm": 57.0,
      "bookWt": 0.18383,
      "inner": 6,
      "caseQty": 48,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1152203100",
      "description": "A4 SC Design SL 100Pg Longbook",
      "orderQty": 36480,
      "oldStock": 0,
      "production": 153240,
      "despatched": 152928,
      "size": "A4 SL DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 100,
      "reelSize": 90.0,
      "cut": 43.0,
      "gsm": 57.0,
      "bookWt": 0.18383,
      "inner": 6,
      "caseQty": 48,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1152201100",
      "description": "A4 SC Design UR 100Pg Longbook",
      "orderQty": 44880,
      "oldStock": 0,
      "production": 36912,
      "despatched": 35136,
      "size": "A4 UR DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 100,
      "reelSize": 90.0,
      "cut": 43.0,
      "gsm": 57.0,
      "bookWt": 0.18383,
      "inner": 6,
      "caseQty": 48,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1152203140",
      "description": "A4 SC Design SL 140Pg Longbook",
      "orderQty": 15000,
      "oldStock": 148,
      "production": 39980,
      "despatched": 40128,
      "size": "A4 SL DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 140,
      "reelSize": 90.0,
      "cut": 43.0,
      "gsm": 57.0,
      "bookWt": 0.25736,
      "inner": 6,
      "caseQty": 48,
      "ups": 3
    },
    {
      "vendor": "Camlin",
      "barcode": "1152201176",
      "description": "A4 SC Design UR 176Pg Longbook",
      "orderQty": 20000,
      "oldStock": 0,
      "production": 15120,
      "despatched": 14976,
      "size": "A4 UR DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 176,
      "reelSize": 90.0,
      "cut": 43.0,
      "gsm": 57.0,
      "bookWt": 0.32353,
      "inner": 6,
      "caseQty": 48,
      "ups": 3
    },
    {
      "vendor": "Camlin",
      "barcode": "1132205056",
      "description": "A5 SC Design 4L 56Pg Copy",
      "orderQty": 36432,
      "oldStock": 44,
      "production": 51760,
      "despatched": 39744,
      "size": "A5 4L DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 56,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 54.0,
      "bookWt": 0.06783,
      "inner": 12,
      "caseQty": 144,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1132203056",
      "description": "A5 SC Design SL 56Pg Copy",
      "orderQty": 30000,
      "oldStock": 30,
      "production": 10217,
      "despatched": 10208,
      "size": "A5 SL DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 56,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 54.0,
      "bookWt": 0.06783,
      "inner": 12,
      "caseQty": 144,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1132201056",
      "description": "A5 SC Design UR 56Pg Copy",
      "orderQty": 50000,
      "oldStock": 0,
      "production": 20000,
      "despatched": 20000,
      "size": "A5 UR DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 56,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 54.0,
      "bookWt": 0.06783,
      "inner": 12,
      "caseQty": 144,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1132103092",
      "description": "A5 SC Brown SL 92Pg Copy",
      "orderQty": 25000,
      "oldStock": 0,
      "production": 0,
      "despatched": 0,
      "size": "A5 SL BROWN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 92,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 57.0,
      "bookWt": 0.11763,
      "inner": 12,
      "caseQty": 96,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1132101092",
      "description": "A5 SC Brown UR 92Pg Copy",
      "orderQty": 20000,
      "oldStock": 0,
      "production": 22636,
      "despatched": 22656,
      "size": "A5 UR BROWN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 92,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 57.0,
      "bookWt": 0.11763,
      "inner": 12,
      "caseQty": 96,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1132203092",
      "description": "A5 SC Design SL 92Pg Copy",
      "orderQty": 20000,
      "oldStock": 0,
      "production": 0,
      "despatched": 0,
      "size": "A5 SL DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 92,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 57.0,
      "bookWt": 0.11763,
      "inner": 12,
      "caseQty": 96,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1132201092",
      "description": "A5 SC Design UR 92Pg Copy",
      "orderQty": 20200,
      "oldStock": 0,
      "production": 0,
      "despatched": 0,
      "size": "A5 UR DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 92,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 57.0,
      "bookWt": 0.11763,
      "inner": 12,
      "caseQty": 96,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1132201140",
      "description": "A5 SC UR DESIGN 120PGS Copy MRP40",
      "orderQty": 18000,
      "oldStock": 0,
      "production": 24967,
      "despatched": 5200,
      "size": "A5 UR DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 120,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 57.0,
      "bookWt": 0.15343,
      "inner": 6,
      "caseQty": 72,
      "ups": 4
    },
    {
      "vendor": "Camlin",
      "barcode": "1132203140",
      "description": "A5 SC SL DESIGN 120PGS Copy MRP40",
      "orderQty": 30000,
      "oldStock": 0,
      "production": 46270,
      "despatched": 0,
      "size": "A5 SL DESIGN",
      "binding": "BACK PRESSED- CENTRE STAPLED",
      "pages": 120,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 57.0,
      "bookWt": 0.15343,
      "inner": 6,
      "caseQty": 72,
      "ups": 4
    },
    {
      "vendor": "ITC",
      "barcode": "1052203240",
      "description": "A4 SC Design SL 240Pg Longbook",
      "orderQty": 10000,
      "oldStock": 0,
      "production": 10000,
      "despatched": 10000,
      "size": "A4 SL DESIGN",
      "binding": "BACK PRESSED",
      "pages": 240,
      "reelSize": 90.0,
      "cut": 43.0,
      "gsm": 57.0,
      "bookWt": 0.44118,
      "inner": 6,
      "caseQty": 36,
      "ups": 3
    },
    {
      "vendor": "ITC",
      "barcode": "1152201076",
      "description": "A4 SC Design UR 76Pg Longbook",
      "orderQty": 12000,
      "oldStock": 0,
      "production": 0,
      "despatched": 0,
      "size": "A4 UR DESIGN",
      "binding": "BACK PRESSED",
      "pages": 76,
      "reelSize": 90.0,
      "cut": 43.0,
      "gsm": 57.0,
      "bookWt": 0.13971,
      "inner": 6,
      "caseQty": 72,
      "ups": 4
    },
    {
      "vendor": "ITC",
      "barcode": "1132203056-ITC",
      "description": "A5 SC Design SL 56Pg Copy (ITC)",
      "orderQty": 160000,
      "oldStock": 0,
      "production": 153240,
      "despatched": 153240,
      "size": "A5 SL DESIGN",
      "binding": "BACK PRESSED",
      "pages": 56,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 54.0,
      "bookWt": 0.06783,
      "inner": 12,
      "caseQty": 144,
      "ups": 4
    },
    {
      "vendor": "ITC",
      "barcode": "1132205092-ITC",
      "description": "A5 SC Design 4L 92Pg Copy (ITC)",
      "orderQty": 38400,
      "oldStock": 0,
      "production": 36912,
      "despatched": 36912,
      "size": "A5 4L DESIGN",
      "binding": "BACK PRESSED",
      "pages": 92,
      "reelSize": 97.0,
      "cut": 37.0,
      "gsm": 57.0,
      "bookWt": 0.11763,
      "inner": 12,
      "caseQty": 96,
      "ups": 4
    },
    {
      "vendor": "Others",
      "barcode": "9901002052",
      "description": "A4 Custom Longbook (Tender Petals)",
      "orderQty": 8000,
      "oldStock": 0,
      "production": 5000,
      "despatched": 4500,
      "size": "A4 CUSTOM",
      "binding": "BACK PRESSED",
      "pages": 64,
      "reelSize": 90.0,
      "cut": 43.0,
      "gsm": 57.0,
      "bookWt": 0.11765,
      "inner": 6,
      "caseQty": 72,
      "ups": 4
    }
  ],
  "papersSummary": [
    {
      "reelSize": "97x37x57",
      "wipType": "A5 SC Copy Cut Sheets",
      "openingWipKg": 0,
      "openingReelsKg": 0,
      "inwardKg": 0,
      "processedKg": 0,
      "wastageKg": 0,
      "wipKg": 0,
      "reelsKg": 0,
      "rate": 77,
      "amount": 0
    },
    {
      "reelSize": "90x43x57",
      "wipType": "A4 SC Longbook Cut Sheets",
      "openingWipKg": 0,
      "openingReelsKg": 0,
      "inwardKg": 0,
      "processedKg": 0,
      "wastageKg": 0,
      "wipKg": 0,
      "reelsKg": 0,
      "rate": 77,
      "amount": 0
    },
    {
      "reelSize": "97x37x54",
      "wipType": "A5 56Pg Cut Sheets",
      "openingWipKg": 0,
      "openingReelsKg": 0,
      "inwardKg": 0,
      "processedKg": 0,
      "wastageKg": 0,
      "wipKg": 0,
      "reelsKg": 0,
      "rate": 77,
      "amount": 0
    }
  ],
  "papersLedger": [],
  "boardSummary": [
    {
      "size": "45.5x91x190",
      "sheetWt": 0.07866,
      "rate": 7.17,
      "openingGodownSheets": 0,
      "openingPrinterSheets": 0,
      "ourGodownSheets": 0,
      "ourGodownKg": 0,
      "printerSheets": 0,
      "printerKg": 0,
      "totalSheets": 0,
      "totalValuation": 0
    },
    {
      "size": "45.5x98x200",
      "sheetWt": 0.0828,
      "rate": 7.54,
      "openingGodownSheets": 0,
      "openingPrinterSheets": 0,
      "ourGodownSheets": 0,
      "ourGodownKg": 0,
      "printerSheets": 0,
      "printerKg": 0,
      "totalSheets": 0,
      "totalValuation": 0
    },
    {
      "size": "91x91x190",
      "sheetWt": 0.1573,
      "rate": 12.755,
      "openingGodownSheets": 0,
      "openingPrinterSheets": 0,
      "ourGodownSheets": 0,
      "ourGodownKg": 0,
      "printerSheets": 0,
      "printerKg": 0,
      "totalSheets": 0,
      "totalValuation": 0
    },
    {
      "size": "91x98x200",
      "sheetWt": 0.1656,
      "rate": 13.435,
      "openingGodownSheets": 0,
      "openingPrinterSheets": 0,
      "ourGodownSheets": 0,
      "ourGodownKg": 0,
      "printerSheets": 0,
      "printerKg": 0,
      "totalSheets": 0,
      "totalValuation": 0
    }
  ],
  "boardLedger": [],
  "boardWipByBarcode": {},
  "consumables": [
    {
      "category": "Inks",
      "item": "RULINK INK (MAGENTA) 30KG PACK",
      "opening": 0,
      "inward": 0,
      "issued": 0,
      "stock": 0,
      "unit": "Pack",
      "rate": 6372,
      "amount": 0
    },
    {
      "category": "Inks",
      "item": "RULINK INK (GREY) 30KG PACK",
      "opening": 0,
      "inward": 0,
      "issued": 0,
      "stock": 0,
      "unit": "Pack",
      "rate": 2006,
      "amount": 0
    },
    {
      "category": "Inks",
      "item": "RULINK INK (BLUE) 30KG PACK",
      "opening": 0,
      "inward": 0,
      "issued": 0,
      "stock": 0,
      "unit": "Pack",
      "rate": 2832,
      "amount": 0
    },
    {
      "category": "Inks",
      "item": "RULINK INK (BLACK) 30KG PACK",
      "opening": 0,
      "inward": 0,
      "issued": 0,
      "stock": 0,
      "unit": "Pack",
      "rate": 2596,
      "amount": 0
    }
  ],
  "financials": {
    "openAdvance": 7169507.88,
    "billDueList": [
      {
        "date": "11.08.2026",
        "invoiceNo": "27/30",
        "amount": 887380
      }
    ],
    "payableToParty": 1263735,
    "receivableFromParty": 0,
    "rawMaterialVal": 0,
    "wipPaperVal": 457417,
    "finishedGoodsList": [
      {
        "barcode": "1132205092",
        "kg": 205,
        "rate": 77.0,
        "amount": 15785
      }
    ]
  },
  "todayTransactions": [
    {
      "id": "tx_today_01",
      "time": "09:15 AM",
      "type": "Order Booking",
      "vendor": "Camlin",
      "barcode": "1152203052",
      "description": "A4 SC Design SL 52Pg Longbook",
      "qty": "15,000 Pcs Booked",
      "impact": "Paper: 1,437.38 Kg | Board: 2,500 Sheets",
      "ref": "PO Camlin / Sep-2026"
    },
    {
      "id": "tx_today_02",
      "time": "10:30 AM",
      "type": "Production",
      "vendor": "Camlin",
      "barcode": "1152203052",
      "description": "A4 SC Design SL 52Pg Longbook",
      "qty": "+5,000 Pcs Produced",
      "impact": "Batch Paper: 479.13 Kg | Board: 625 Sheets",
      "ref": "Lineomatic 1 (Shift A)"
    },
    {
      "id": "tx_today_03",
      "time": "11:45 AM",
      "type": "Despatch",
      "vendor": "Camlin",
      "barcode": "1152203052",
      "description": "A4 SC Design SL 52Pg Longbook",
      "qty": "2,500 Pcs Despatched",
      "impact": "Remaining Godown Stock: 24,212 Pcs",
      "ref": "Challan: SPC/26-27/045 (WB-23-4567)"
    },
    {
      "id": "tx_today_04",
      "time": "01:10 PM",
      "type": "Materials",
      "vendor": "Mill / Raw Paper",
      "barcode": "90x43x57",
      "description": "A4 SC Longbook Cut Sheets (90x43x57)",
      "qty": "+2,260.08 Kg Slitted",
      "impact": "Wastage: 21.92 Kg | WIP: 2,260.08 Kg",
      "ref": "Batch PR-1124"
    },
    {
      "id": "tx_today_05",
      "time": "02:30 PM",
      "type": "Materials",
      "vendor": "Fortune Graphics",
      "barcode": "45.5x91x190",
      "description": "Printed Board Covers (45.5x91x190)",
      "qty": "+52,400 Sheets Recd",
      "impact": "Godown Bal: 52,400 | Printer Bal: 7,000 Sheets",
      "ref": "DC-129"
    },
    {
      "id": "tx_today_06",
      "time": "03:45 PM",
      "type": "Production",
      "vendor": "Camlin",
      "barcode": "1152203100",
      "description": "A4 SC Design SL 100Pg Longbook",
      "qty": "+10,000 Pcs Produced",
      "impact": "Batch Paper: 1,838.30 Kg | Board: 2,500 Sheets",
      "ref": "Lineomatic 2 (Shift B)"
    }
  ],
  "poRequests": [],
  "poReleases": [],
  "poTrackings": [],
  "materialStock": {
    "paper": {
      "90x43x57": {
        "Reel Form": 0,
        "Single Line": 0,
        "Double Rule": 0,
        "Unruled": 0,
        "Four Line": 0,
        "Med. Square": 0,
        "Index": 0
      },
      "97x37x54": {
        "Reel Form": 0,
        "Single Line": 0,
        "Double Rule": 0,
        "Unruled": 0,
        "Four Line": 0,
        "Med. Square": 0,
        "Index": 0
      },
      "97x37x57": {
        "Reel Form": 0,
        "Single Line": 0,
        "Double Rule": 0,
        "Unruled": 0,
        "Four Line": 0,
        "Med. Square": 0,
        "Index": 0
      }
    },
    "board": {
      "45.5 x 91 x 190": 0,
      "45.5 x 91 x 200": 0,
      "77 x 98 x 190": 0
    }
  },
  "dailyFlashReports": [],
  "ranjitMakingEntries": []
};
  folder.createFile(FILE_NAME, JSON.stringify(initialData, null, 2), MimeType.PLAIN_TEXT);
  return initialData;
}

function saveToDriveFile(dataObj) {
  const folder = getOrCreateMasterFolder();
  const files = folder.getFilesByName(FILE_NAME);
  const jsonStr = JSON.stringify(dataObj, null, 2);

  if (files.hasNext()) {
    const file = files.next();
    // Native Google Drive Versioning: Keeps version history of every save
    file.setContent(jsonStr);
  } else {
    folder.createFile(FILE_NAME, jsonStr, MimeType.PLAIN_TEXT);
  }
}
