const MAINNET_LDPLuckyDraw = artifacts.require("LDPLuckyDraw");
const TESTNET_LDPLuckyDraw = artifacts.require("LDPLuckyDraw_TESTNET");

const DO_DEPLOY = process.env.DEPLOY_LUCKY_DRAW;
const USE_TESTNET_CONTRACT = process.env.USE_LUCKYDRAW_TESTNET_CONTRACT;

let LDPLuckyDraw;
if (USE_TESTNET_CONTRACT==1){
  LDPLuckyDraw = TESTNET_LDPLuckyDraw;
}
else {
  LDPLuckyDraw = MAINNET_LDPLuckyDraw;
}

module.exports = function (deployer) {
  if (DO_DEPLOY==1) {
    deployer.deploy(LDPLuckyDraw);
  }
};
