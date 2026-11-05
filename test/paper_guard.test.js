// Run with: node test/paper_guard.test.js
const assert = require('assert');
require('../web/paper_guard.js');
const { isBlockedRequest: req, isBlockedSite: site } = globalThis.__paperGuard;
const go = 'https://go.mynt.in/NorenWClientWeb/';

for (const e of ['PlaceOrder', 'ModifyOrder', 'CancelOrder', 'ExitSNOOrder', 'ProductConversion',
  'PlaceGTTOrder', 'ModifyGTTOrder', 'CancelGTTOrder', 'PlaceOCOOrder', 'ModifyOCOOrder',
  'PlaceSipOrder', 'ModifySipOrder', 'CancelSipOrder']) assert(req(go + e), e);
for (const u of ['https://v3.mynt.in/ipo/addIPOtoPortfolio', 'https://v3.mynt.in/mf/lumsum_purchase',
  'https://v3.mynt.in/mf/lumsum_redemption_cancel', 'https://v3.mynt.in/mfapi/order/xsip_purchase',
  'https://v3.mynt.in/mfapi/order/PlaceRedeemOrder', 'https://fundapi.mynt.in/withdraw/payment',
  'https://rekycbe.mynt.in/pledge//del_pledge']) assert(req(u), u);
for (const e of ['OrderBook', 'GetQuotes', 'GetOrderMargin', 'SearchScrip', 'CancelAlert', 'TradeBook'])
  assert(!req(go + e), e);

for (const p of ['mail_otpsend', 'file_write_email', 'mob_otp_ver', 'file_write_mob', 'adr_chn', 'bank', 'DDPI', 'mtf', 'income', 'nominee', 'add_segment', 'img_upload', 'cdsl/signature_upload', 'send_link_request', 'closure']) {
  assert(req('https://rekycbe.mynt.in/' + p), p);
  assert(req('https://rekycbe.mynt.in//' + p), p);
}
for (const e of ['UserApiKeyRenReq', 'GetUserApiKey', 'AppKeyStore', 'GenSecretKey']) assert(req(go + e), e);
for (const a of ['create', 'update', 'delete']) assert(req('https://ws.mynt.in/login//oauth-apps/' + a), a);
assert(!req('https://ws.mynt.in/login//oauth-apps/list'));
for (const p of ['profile', 'check_closure', 'getholdingscheck', 'nom_stat', 'add_mob_email_stat', 'cdsl/signature_check', 'filedownload'])
  assert(!req('https://rekycbe.mynt.in//' + p), p);

for (const u of ['https://fund.zebuetrade.com?uid=A&token=B', 'https://fund.zebuetrade.com/withdrawal',
  'https://algo.zebuetrade.com/marketplace', 'https://profile.zebuetrade.com/refer?uid=A&token=B',
  'https://go.mynt.in/x?token=B']) assert(site(u), u);
for (const u of ['https://oa.mynt.in/?ref=A', 'https://www.nseindia.com/', 'https://zebuetrade.com/'])
  assert(!site(u), u);
console.log('paper_guard: all checks passed');
