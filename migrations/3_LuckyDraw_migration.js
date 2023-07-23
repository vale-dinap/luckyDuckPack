const LDPLuckyDraw = artifacts.require("LDPLuckyDraw");

const DO_DEPLOY = process.env.DEPLOY_LUCKY_DRAW;

module.exports = function (deployer) {
  if (DO_DEPLOY) {
    deployer.deploy(LDPLuckyDraw);
  }
};
