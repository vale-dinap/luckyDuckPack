// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/interfaces/ILDP.sol";

/**
 * @dev Lucky Duck Pack Minter
 *
 * This contract manages the LDP collection minting process.
 *
 * We strongly recommend to thoroughly examine the code before
 * interacting with it.
 *
 * To assist in the review process, ample comments have been included
 * throughout the code.
 *
 * Like all other LuckyDuckPack contracts, this one aims to be 100%
 * fair, secure, trustworthy and efficient.
 *
 * This is accomplished through features including:
 * -The administrator's privileges are very limited and, once the
 *  minting process begins, the majority of the contract data becomes
 *  immutable.
 * -The initiation of minting is determined by a set time, and once it
 *  begins, it cannot be stopped.
 * -Variables such as prices are hardcoded to ensure transparency and
 *  lower gas fees.
 * -Token distribution and reveal are ensured to be fair and secure from
 *  hacking, thanks to the use of Chainlink VRF - Further information can
 *  be found in the NFT contract.
 * -The design of the mint function has been kept minimal to reduce its gas
 *  costs: it doesn't even forward funds to the creator, who has to
 *  manually withdraw them instead.
 * -A portion of the payment is immediately distributed to token holders as
 *  a starting incentive/cashback, with the smart contract enforcing the
 *  distribution.
 */
contract LDPMinter is Ownable, ReentrancyGuard {
    // Pricing - hardcoded for transparency and efficiency
    uint256 private constant _price1 = 1.3 ether; // From 1 to 3333
    uint256 private constant _price2 = 1.8 ether; // From 3334 to 6666
    uint256 private constant _price3 = 2.3 ether; // From 6667 to 10000
    // Minting start time (Unix timestamp)
    uint256 public mintingStartTime;
    // Instance of the token contract
    ILDP public nft;
    // LDP Rewarder contract address
    address public rewarder;
    // Creator
    address private creator;
    // Total supply at last proceeds withdraw
    uint256 private supplyAtLastWithdraw = 20; // Start at 20 due to team-reserved tokens

    // Custom errors
    error MaxMintsPerCallExceeded();
    error PricePaidIncorrect();
    error MintingNotStarted();
    error PaymentError(bool successA, bool successB);

    /**
     * @notice Link the token contract to the nft contract address.
     * Can be set only once, then it becomes immutable.
     */
    function setNftAddress(address nftAddr) external onlyOwner {
        require(address(nft) == address(0), "Overriding denied");
        nft = ILDP(nftAddr);
    }

    /**
     * @notice Set the creator address.
     */
    function setCreatorAddress(address creatorAddr) external onlyOwner {
        require(creatorAddr != address(0), "Input is zero address");
        creator = creatorAddr;
    }

    /**
     * @notice Set the LDP Rewarder contract address. Locked after minting starts.
     */
    function setRewarderAddress(address rewarderAddr) external onlyOwner {
        require(
            block.timestamp < mintingStartTime,
            "Access denied: minting started"
        );
        require(rewarderAddr != address(0), "Input is zero address");
        rewarder = rewarderAddr;
    }

    /**
     * @notice Set minting start time and reserve 20 tokens to admin's address.
     * Half of these tokens will be used for giveaways, half will be gifted
     * to the team.
     * @dev This function can be called only once, so admin won't be able to
     * mint more than 20 free tokens.
     * @param startTime Minting start time (Unix timestamp)
     */
    function initializeMinting(uint256 startTime) external onlyOwner {
        if (mintingStartTime != 0) revert("Already initialized");
        else {
            require(
                startTime > block.timestamp,
                "Requested time is in the past"
            );
            mintingStartTime = startTime;
            _mintBatch(20);
        }
    }

    /**
     * @notice Mint (buy) tokens to the caller address.
     * @param amount Number of tokens to be minted, max 10 per transaction.
     */
    function mint(uint256 amount) external payable nonReentrant {
        // Revert if minting hasn't started
        if(block.timestamp < mintingStartTime) revert MintingNotStarted();
        // Revert if attempting to mint more than 10 tokens at once
        if (amount > 10) revert MaxMintsPerCallExceeded();
        // Revert if underpaying
        unchecked{
            if(msg.value < _currentPrice() * amount) revert PricePaidIncorrect();
        }
        // Finally, mint the tokens
        _mintBatch(amount);
    }

    /**
     * @notice Shows how many tokens are left to be minted.
     */
    function mintableSupply() external view returns (uint256) {
        return nft.MAX_SUPPLY() - nft.totalSupply();
    }

    /**
     * @notice Shows the current price.
     */
    function currentPrice() external view returns (uint256) {
        return _currentPrice();
    }

    /**
     * @notice Send proceeds to creator address and incentives to Rewarder contract.
     */
    function withdrawProceeds() external {
        require(mintingStartTime != 0, "Called before initializeMinting");
        uint256 currentSupply = nft.totalSupply();
        uint256 newSales = currentSupply - supplyAtLastWithdraw;
        supplyAtLastWithdraw = currentSupply;
        _processWithdraw(newSales);
    }

    /**
     * @dev Returns the current price (depending on the remaining supply).
     */
    function _currentPrice() private view returns (uint256) {
        uint256 curSupply = nft.totalSupply();
        if (curSupply < 3334) return _price1;
        else if (curSupply < 6667) return _price2;
        else return _price3;
    }

    /**
     * @dev Mint multiple tokens.
     */
    function _mintBatch(uint256 amount) private {
        for (uint256 i; i < amount;) {
            nft.mint(msg.sender);
            unchecked{++i;}
        }
    }

    /**
     * @dev Send proceeds to creator address and incentives to rewarder contract.
     * @param newTokensSold Number of new sales
     */
    function _processWithdraw(uint256 newTokensSold) private {
        uint256 incentivesPerSale = 0.25 ether;
        uint256 totalIncentives = incentivesPerSale * newTokensSold;
        uint256 _bal = address(this).balance;
        if (totalIncentives < _bal) {
            uint256 creatorProceeds = _bal - totalIncentives;
            (bool creatorPaid, ) = creator.call{value: creatorProceeds}("");
            (bool rewarderPaid, ) = rewarder.call{value: totalIncentives}("");
            if (!(creatorPaid && rewarderPaid))
                revert PaymentError(creatorPaid, rewarderPaid);
        } else {
            // Emergency measure to prevent funds from remaining stuck in the
            // contract if something goes wrong: has no effect as long as the
            // contract works as intended.
            payable(creator).transfer(_bal);
        }
    }
}