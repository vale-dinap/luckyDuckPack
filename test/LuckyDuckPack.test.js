const { assert } = require("chai");
const { expectRevertCustomError } = require("custom-error-test-helper");
const {
  BN,
  constants,
  expectEvent,
  shouldFail,
  time,
} = require("@openzeppelin/test-helpers");
const {
  LuckyDuckPack,
  LDPMinter,
  LDPRewarder,
  VRFCoordinator,
  Link,
  ERC20TokenA,
  ERC20TokenB,
  initContracts
} = require("./common/contractsInit.js");

contract("Token contract", async (accounts) => {

  var admin, creator, payout, userA, userB, userC;

  before(async function () {
    // Address aliases
    admin = accounts[0];
    creator = accounts[8];
    payout = accounts[9];
    userA = accounts[1];
    userB = accounts[2];
    userC = accounts[3];
  });

  beforeEach(async function () {
    // Create contracts
    [
      nftContract,
      minterContract,
      rewarderContract,
      VRFContract,
      linkContract,
      tokenAContract,
      tokenBContract
    ] = await initContracts(creator, payout);
  });

  describe("Deployment", function () {
    it("PLACEHOLDER", async () => {

    });

  });

});
