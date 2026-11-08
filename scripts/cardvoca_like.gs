// Deploy as an Apps Script web app: execute as the owner, access by anyone.
// This endpoint accepts only a like event. It never reads account or device data.
const SHEET_NAME = '좋아요';
const MAX_LIKES_PER_DAY = 100000;

function doGet() {
  return reply_({ ok: true, service: 'CardVoca likes' });
}

function doPost(e) {
  try {
    const contents = e && e.postData && e.postData.contents;
    if (typeof contents !== 'string' || contents.length > 100) return reply_({ ok: false });
    const request = JSON.parse(contents);
    if (request.type !== 'like' || Object.keys(request).length !== 1) return reply_({ ok: false });

    const day = Utilities.formatDate(new Date(), 'Asia/Seoul', 'yyyy-MM-dd');
    const lock = LockService.getScriptLock();
    lock.waitLock(5000);
    let count;
    try {
      const sheetId = PropertiesService.getScriptProperties().getProperty('LIKES_SHEET_ID');
      if (!sheetId) throw new Error('Missing LIKES_SHEET_ID');
      const sheet = SpreadsheetApp.openById(sheetId).getSheetByName(SHEET_NAME);
      if (!sheet) throw new Error('Missing likes sheet');
      const lastRow = sheet.getLastRow();
      const lastDay = lastRow > 1 ? String(sheet.getRange(lastRow, 1).getDisplayValue()) : '';
      const previous = lastDay === day ? Number(sheet.getRange(lastRow, 2).getValue()) : 0;
      if (previous >= MAX_LIKES_PER_DAY) return reply_({ ok: false, full: true });
      count = previous + 1;
      if (lastDay === day) sheet.getRange(lastRow, 2).setValue(count);
      else sheet.appendRow([day, count]);
    } finally {
      lock.releaseLock();
    }

    return reply_({ ok: true });
  } catch (_) {
    return reply_({ ok: false });
  }
}

function reply_(value) {
  return ContentService.createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}
