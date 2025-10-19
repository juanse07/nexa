// Run this in the browser console to clear all storage
console.log('Clearing all storage...');

// Clear localStorage
localStorage.clear();
console.log('✓ localStorage cleared');

// Clear sessionStorage
sessionStorage.clear();
console.log('✓ sessionStorage cleared');

// Clear all cookies for this domain
document.cookie.split(";").forEach(function(c) {
  document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/");
});
console.log('✓ Cookies cleared');

// Clear IndexedDB
if (window.indexedDB) {
  indexedDB.databases().then(databases => {
    databases.forEach(db => {
      indexedDB.deleteDatabase(db.name);
      console.log(`✓ IndexedDB ${db.name} cleared`);
    });
  }).catch(e => console.log('IndexedDB clear failed:', e));
}

console.log('All storage cleared! Please refresh the page and log in again.');