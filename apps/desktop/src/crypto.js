const { safeStorage } = require('electron');

function encrypt(value) {
  if (value === undefined || value === null || value === '') return null;
  if (!safeStorage.isEncryptionAvailable()) {
    throw new Error('Windows secure storage is not available on this computer.');
  }
  return safeStorage.encryptString(String(value)).toString('base64');
}

function decrypt(value) {
  if (!value) return '';
  if (!safeStorage.isEncryptionAvailable()) {
    throw new Error('Windows secure storage is not available on this computer.');
  }
  return safeStorage.decryptString(Buffer.from(value, 'base64'));
}

module.exports = { encrypt, decrypt };
