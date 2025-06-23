function handleUpdateRepair(data) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('แจ้งซ่อม');
  const values = sheet.getDataRange().getValues();
  const headers = values[0];
  
  // หาแถวที่ต้องการอัพเดท
  const rowIndex = values.findIndex(row => row[0] === data['เลขที่ใบแจ้งซ่อม']);
  if (rowIndex === -1) {
    return formatResponse({
      status: 'error',
      message: 'ไม่พบข้อมูลที่ต้องการอัพเดท'
    });
  }

  // อัพเดทข้อมูล
  Object.keys(data).forEach(key => {
    const colIndex = headers.indexOf(key);
    if (colIndex !== -1) {
      sheet.getRange(rowIndex + 1, colIndex + 1).setValue(data[key]);
    }
  });

  // อัพเดทเวลาถ้ามีการเปลี่ยนสถานะ
  if (data['สถานะ']) {
    const now = new Date();
    if (data['สถานะ'] === 'ยังไม่ดำเนินการ') {
      // อัพเดทเวลาที่ช่างรับงาน
      const timeColIndex = headers.indexOf('เวลาเริ่มซ่อม');
      if (timeColIndex !== -1) {
        sheet.getRange(rowIndex + 1, timeColIndex + 1).setValue(now);
      }
    } else if (data['สถานะ'] === 'ดำเนินการเสร็จสิ้น') {
      // อัพเดทเวลาที่ซ่อมเสร็จ
      const timeColIndex = headers.indexOf('เวลาซ่อมสำเร็จ');
      if (timeColIndex !== -1) {
        sheet.getRange(rowIndex + 1, timeColIndex + 1).setValue(now);
      }
    }
  }

  return formatResponse({
    status: 'success',
    message: 'อัพเดทข้อมูลเรียบร้อยแล้ว',
    updatedData: {
      เลขที่ใบแจ้งซ่อม: data['เลขที่ใบแจ้งซ่อม'],
      สถานะ: data['สถานะ'],
      ช่างผู้ซ่อม: data['ช่างผู้ซ่อม'],
      เวลาเริ่มซ่อม: data['สถานะ'] === 'ยังไม่ดำเนินการ' ? new Date() : null,
      เวลาซ่อมสำเร็จ: data['สถานะ'] === 'ดำเนินการเสร็จสิ้น' ? new Date() : null
    }
  });
}

function handleUpdateRating(data) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('แจ้งซ่อม');
  const values = sheet.getDataRange().getValues();
  const headers = values[0];
  
  // หาแถวที่ต้องการอัพเดท
  const rowIndex = values.findIndex(row => row[0] === data['เลขที่ใบแจ้งซ่อม']);
  if (rowIndex === -1) {
    return formatResponse({
      status: 'error',
      message: 'ไม่พบข้อมูลที่ต้องการอัพเดท'
    });
  }

  // หาคอลัมน์ดาวประเมิน
  const ratingColIndex = headers.indexOf('ดาวประเมิน');
  if (ratingColIndex === -1) {
    return formatResponse({
      status: 'error',
      message: 'ไม่พบคอลัมน์ดาวประเมิน กรุณาเพิ่มคอลัมน์ "ดาวประเมิน" ในชีท'
    });
  }

  // อัพเดทดาวประเมิน
  const rating = parseInt(data['ดาวประเมิน']) || 0;
  if (rating < 1 || rating > 5) {
    return formatResponse({
      status: 'error',
      message: 'ดาวประเมินต้องอยู่ระหว่าง 1-5'
    });
  }

  sheet.getRange(rowIndex + 1, ratingColIndex + 1).setValue(rating);

  // อัพเดทเวลาประเมิน
  const timeColIndex = headers.indexOf('เวลาประเมิน');
  if (timeColIndex !== -1) {
    sheet.getRange(rowIndex + 1, timeColIndex + 1).setValue(new Date());
  }

  return formatResponse({
    status: 'success',
    message: 'บันทึกการประเมินเรียบร้อยแล้ว',
    updatedData: {
      เลขที่ใบแจ้งซ่อม: data['เลขที่ใบแจ้งซ่อม'],
      ดาวประเมิน: rating,
      เวลาประเมิน: new Date()
    }
  });
}

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const action = data.action;

    switch(action) {
      case 'createRepair':
        return handleCreateRepair(data);
      case 'updateRepair':
        return handleUpdateRepair(data);
      case 'updateRating':
        return handleUpdateRating(data);
      case 'getRepair':
        return handleGetRepair(data);
      case 'login':
        return handleLogin(data);
      case 'logout':
        return handleLogout(data);
      case 'updateProfile':
        return handleUpdateProfile(data);
      case 'getSettings':
        return handleGetSettings(data);
      case 'updateSettings':
        return handleUpdateSettings(data);
      default:
        return formatResponse({
          status: 'error',
          message: 'Invalid action'
        });
    }

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      result: 'error',
      message: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function saveWorkReport(data) {
  try {
    const workItems = data.data;
    const technician = data.technician;

    const spreadsheet = SpreadsheetApp.openById('167IUXdNWqG0tAHkQ7QKIzuheQosP7ykRlFQnzn9kKRk');
    const sheet = spreadsheet.getSheetByName('WorkReports') || spreadsheet.insertSheet('WorkReports');

    if (sheet.getLastRow() === 0) {
      const headers = ['วันที่', 'งานที่แจ้ง', 'ผู้แจ้ง', 'โซน', 'เวลาแจ้ง', 'เวลาที่ซ่อมเสร็จ', 'ผู้ซ่อม', 'ประเภทงานแจ้ง', 'ใบแจ้ง', 'PM', 'BD'];
      sheet.appendRow(headers);
    }

    workItems.forEach(item => {
      const row = [
        item['วันที่'],
        item['งานที่แจ้ง'],
        item['ผู้แจ้ง'],
        item['โซน'],
        item['เวลาแจ้ง'],
        item['เวลาที่ซ่อมเสร็จ'],
        item['ผู้ซ่อม'],
        item['ประเภทงานแจ้ง'],
        item['ใบแจ้ง'],
        item['PM'],
        item['BD']
      ];
      sheet.appendRow(row);
    });

    return ContentService.createTextOutput(JSON.stringify({
      result: 'success',
      message: `บันทึก ${workItems.length} รายการสำเร็จ`,
      technician: technician
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      result: 'error',
      message: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function handleCreateRepair(data) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('แจ้งซ่อม');
  
  // อัปโหลด QR base64 ไป Google Drive
  var qrUrl = '';
  if (data['Qrเครื่องจักร'] && data['Qrเครื่องจักร'] !== '') {
    try {
      var base64 = data['Qrเครื่องจักร'];
      var filename = data['Qrเครื่องจักร_filename'] || ('qr_' + new Date().getTime() + '.jpg');
      var contentType = 'image/jpeg';
      var bytes = Utilities.base64Decode(base64);
      var blob = Utilities.newBlob(bytes, contentType, filename);

      var folder = DriveApp.getFolderById('1k2VuDp7YR8YcUYtCFS4D7Y74qWuCIUZw');
      var file = folder.createFile(blob);
      qrUrl = file.getUrl();
    } catch (err) {
      qrUrl = '';
    }
  }

  // สร้างแถวข้อมูลใหม่
  const newRow = [
    data['เลขที่ใบแจ้งซ่อม'],
    qrUrl,
    data['วันที่แจ้ง'],
    data['ชื่อผู้แจ้ง'],
    data['แผนก'],
    data['MachineName'],
    data['MachineID'],
    data['รายละเอียด'],
    data['ประเภทการแจ้ง'],
    data['ประเภทงาน'],
    data['สถานะ'],
    '', // ผู้รับแจ้ง
    '', // ช่างผู้ซ่อม
    '', // อะไหล่ที่ใช้
    '', // เวลาเริ่มซ่อม
    '', // เวลาซ่อมสำเร็จ
    '', // รูปอื่นๆ
    '', // เวลาประเมิน
    '', // ดาวประเมิน
  ];

  sheet.appendRow(newRow);

  return formatResponse({
    status: 'success',
    message: 'บันทึกข้อมูลเรียบร้อยแล้ว',
    ticketId: data['เลขที่ใบแจ้งซ่อม'],
    qrUrl: qrUrl
  });
} 