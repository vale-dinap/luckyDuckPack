// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
 * Like all other Lucky Duck Pack contracts, this aims to be 100% fair,
 * secure, trustworthy and efficient.
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
    // Number of tokens reserved to the team
    uint256 private constant _teamReserved = 20;
    // Minting start time (Unix timestamp)
    uint256 public mintingStartTime;
    // Instance of the token contract
    ILDP public nft;
    // LDP Rewarder contract address
    address public rewarder;
    // Creator
    address private creator;
    // Total supply at last proceeds withdraw - required to track the incentives that have already been sent
    uint256 private supplyAtLastWithdraw = _teamReserved; // Start at [_teamReserved] (as these won't be paid)


    // =============================================================
    //                        CUSTOM ERRORS
    // =============================================================

    error InputIsZero(); // When using address(0) as function parameter
    error MintingNotStarted(); // Attempting to mint earlier than [mintingStartTime]
    error MintingAlreadyStarted(); // Attempting to perform setup operations later than [mintingStartTime]
    error MaxMintsPerCallExceeded(); // Attempting to mint more than 10 NFTs at once
    error PricePaidIncorrect(); // Returned when underpaying
    error PaymentError(bool successA, bool successB); // Transfer error


    // =============================================================
    //                         FUNCTIONS
    // =============================================================

    /**
     * @notice Mint (buy) tokens to the caller address.
     * @param amount Number of tokens to be minted, max 10 per transaction.
     */
    function mint(uint256 amount) external payable nonReentrant {
        // Revert if minting hasn't started
        if (block.timestamp < mintingStartTime) revert MintingNotStarted();
        // Revert if attempting to mint more than 10 tokens at once
        if (amount > 10) revert MaxMintsPerCallExceeded();
        // Revert if underpaying
        unchecked {
            if (msg.value < _currentPrice_t6y() * amount)
                revert PricePaidIncorrect();
        }
        // Finally, mint the tokens
        _mintBatch_K2B(amount);
    }

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
        if (creatorAddr == address(0)) revert InputIsZero();
        creator = creatorAddr;
    }

    /**
     * @notice Set the LDP Rewarder contract address. Locked after minting starts.
     */
    function setRewarderAddress(address rewarderAddr) external onlyOwner {
        uint256 _startTime = mintingStartTime;
        if (_startTime != 0) {
            if (block.timestamp > _startTime) revert MintingAlreadyStarted();
        }
        if (rewarderAddr == address(0)) revert InputIsZero();
        rewarder = rewarderAddr;
    }

    /**
     * @notice Set minting start time and reserve [_teamReserved] tokens to
     * admin's address.
     * Some of these tokens will be used for giveaways, the rest will be
     * gifted to the team.
     * @dev This function can be called only once, so admin won't be able to
     * mint more than [_teamReserved] free tokens.
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
            _mintBatch_K2B(_teamReserved);
        }
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
        return _currentPrice_t6y();
    }

    /**
     * @notice Send proceeds to creator address and incentives to Rewarder contract.
     * @dev Reverts if the transfers fail.
     */
    function withdrawProceeds() external {
        require(mintingStartTime != 0, "Called before initializeMinting");
        if (_msgSender() != owner())
            require(_msgSender() == creator, "Caller is not admin nor creator");
        uint256 currentSupply = nft.totalSupply();
        uint256 newSales = currentSupply - supplyAtLastWithdraw;
        supplyAtLastWithdraw = currentSupply; // Storage variable update
        // Actual withdraw
        (bool creatorPaid, bool rewarderPaid) = _processWithdraw_ama(newSales);
        // Revert if one or both payments failed
        if (!(creatorPaid && rewarderPaid))
            revert PaymentError(creatorPaid, rewarderPaid);
    }

    /**
     * @notice Emergency function to recover funds that may be trapped in the contract
     * in the event of unforeseen circumstances preventing {withdrawProceeds} from
     * functioning as intended. This function is subject to strict limitations:
     * it cannot be utilized prior to the completion of the minting process, it
     * initially attempts a regular withdrawal (to prevent potential exploitation by
     * the admin), and only in case that fails, it sends any remaining funds to the
     * admin's address. The admin will then be responsible for distributing the
     * proceeds manually.
     */
    function emergencyWithdraw() external onlyOwner {
        // Revert if the function is called before the minting process ends
        uint256 currentSupply = nft.totalSupply();
        require(nft.totalSupply() == nft.MAX_SUPPLY(), "Minting in progress");
        // Attempt the normal withdraw first: if succeeds, emergency actions won't be performed
        uint256 newSales = currentSupply - supplyAtLastWithdraw;
        supplyAtLastWithdraw = currentSupply;
        (bool creatorPaid, bool rewarderPaid) = _processWithdraw_ama(newSales);
        // If one of the two payments failed, send the remaining balance to admin
        if (!(creatorPaid && rewarderPaid)) {
            uint256 _bal = address(this).balance;
            payable(_msgSender()).transfer(_bal);
        }
    }


    // =============================================================
    //                      PRIVATE FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the current price (depending on the remaining supply).
     */
    function _currentPrice_t6y() private view returns (uint256) {
        uint256 curSupply = nft.totalSupply();
        if (curSupply < 3334) return _price1;
        else if (curSupply < 6667) return _price2;
        else return _price3;
    }

    /**
     * @dev Mint multiple tokens.
     */
    function _mintBatch_K2B(uint256 amount) private {
        for (uint256 i; i < amount; ) {
            nft.mint_i5a(msg.sender);
            unchecked {++i;}
        }
    }

    /**
     * @dev Send proceeds to creator address and incentives to rewarder contract.
     * @param newTokensSold Number of new sales
     */
    function _processWithdraw_ama(uint256 newTokensSold)
        private
        returns (bool creatorPaid, bool rewarderPaid)
    {
        uint256 incentivesPerSale = 0.25 ether;
        uint256 totalIncentives = incentivesPerSale * newTokensSold;
        uint256 _bal = address(this).balance;
        if (totalIncentives < _bal) {
            uint256 creatorProceeds = _bal - totalIncentives;
            (rewarderPaid, ) = rewarder.call{value: totalIncentives}("");
            (creatorPaid, ) = creator.call{value: creatorProceeds}("");
        }
    }
}

// :)