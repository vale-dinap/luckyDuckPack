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
 * We strongly recommend to thoroughly examine the code before interacting
 * with it.
 *
 * To assist in the review process, ample comments have been included
 * throughout the code.
 *
 * Like all other Lucky Duck Pack contracts, this aims to be fair, secure,
 * trustworthy and efficient.
 *
 * This is accomplished through features including:
 * -The administrator's privileges are very limited and, once the minting
 *  process begins, they are further restricted to payout functions only.
 * -Variables such as prices are hardcoded to ensure transparency and lower
 *  gas fees.
 * -Token distribution and reveal are ensured to be fair and secure from
 *  hacking, thanks to the use of Chainlink VRF - Further information can
 *  be found in the NFT contract.
 * -The design of the mint function has been kept minimal to reduce its gas
 *  costs.
 * -A portion of the payment is immediately distributed to token holders as
 *  a starting incentive/cashback, with the smart contract enforcing the
 *  distribution.
 */
contract LDPMinter is Ownable, ReentrancyGuard {

    // =============================================================
    //                     CONTRACT VARIABLES
    // =============================================================

    // Pricing - hardcoded for transparency and efficiency
    uint256 private constant _PRICE1 = 1.3 ether; // From 1 to 3333
    uint256 private constant _PRICE2 = 1.8 ether; // From 3334 to 6666
    uint256 private constant _PRICE3 = 2.3 ether; // From 6667 to 10000
    // Number of tokens reserved to the team
    uint256 private constant _TEAM_RESERVED = 25;
    // When the admin sets this to 'true', minting is enabled and cannot be reverted back to 'false'
    bool public mintingStarted;
    // Instance of the token contract
    ILDP public nft;
    // LDP Rewarder contract address
    address public rewarder;
    // Creator
    address private creator;
    // Total supply at last proceeds withdraw - required to track the incentives that have already been sent
    uint256 private supplyAtLastWithdraw = _TEAM_RESERVED; // Start at [_TEAM_RESERVED] (as these won't be paid)

    // =============================================================
    //                  CUSTOM ERRORS AND EVENTS
    // =============================================================

    event MintingStarted(); // Emitted when the minting is opended

    error InputIsZero(); // When using address(0) as function parameter
    error MintingNotStarted(); // Attempting to mint before [mintingStarted] is enabled
    error MintingAlreadyStarted(); // Attempting operations forbidden after the minting begins
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
        if (!mintingStarted) revert MintingNotStarted();
        // Revert if attempting to mint more than 10 tokens at once
        if (amount > 10) revert MaxMintsPerCallExceeded();
        // Revert if underpaying
        unchecked {
            if (msg.value < _currentPrice_t6y() * amount)
                revert PricePaidIncorrect();
        }
        // Finally, mint the tokens
        _mint_Ei7(amount);
    }

    /**
     * @notice Link the Minter to the the NFT contract and the Rewarder
     * contract; also sets the creator address; this function can be
     * called only by the admin, and only until the minting hasn't started.
     */
    function initializeContract(
        address nftAddr,
        address rewarderAddr,
        address creatorAddr
    ) external onlyOwner {
        if (mintingStarted) revert MintingAlreadyStarted();
        if (rewarderAddr == address(0)) revert InputIsZero();
        if (creatorAddr == address(0)) revert InputIsZero();
        if (nftAddr == address(0)) revert InputIsZero();
        nft = ILDP(nftAddr);
        rewarder = rewarderAddr;
        creator = creatorAddr;
    }

    /**
     * @notice Enable minting and mint [_TEAM_RESERVED] tokens to admin's
     * address. Some of these tokens will be used for giveaways, the rest
     * will be gifted to the team.
     * @dev This function can be called only once, so admin won't be able to
     * mint more than [_TEAM_RESERVED] free tokens.
     */
    function initializeMinting() external onlyOwner {
        if (mintingStarted) revert MintingAlreadyStarted();
        mintingStarted = true;
        _mint_Ei7(_TEAM_RESERVED);
        emit MintingStarted();
    }

    /**
     * @notice Set the creator address.
     */
    function setCreatorAddress(address creatorAddr) external onlyOwner {
        if (creatorAddr == address(0)) revert InputIsZero();
        creator = creatorAddr;
    }

    /**
     * @notice Shows how many tokens are left to be minted.
     */
    function mintableSupply() external view returns (uint256 supply) {
        unchecked {
            supply = nft.MAX_SUPPLY() - nft.totalSupply();
        }
    }

    /**
     * @notice Show the current price.
     */
    function currentPrice() external view returns (uint256) {
        return _currentPrice_t6y();
    }

    /**
     * @notice Send proceeds to creator address and incentives to Rewarder contract.
     * @dev Reverts if the transfers fail.
     */
    function withdrawProceeds() external {
        if (!mintingStarted) revert MintingNotStarted();
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
        require(currentSupply == nft.MAX_SUPPLY(), "Minting still in progress");
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
     * @dev Mint `amount` tokens to sender address.
     */
    function _mint_Ei7(uint256 amount) private {
        nft.mint_Qgo(msg.sender, amount);
    }

    /**
     * @dev Returns the current price (depending on the remaining supply).
     */
    function _currentPrice_t6y() private view returns (uint256) {
        uint256 curSupply = nft.totalSupply();
        if (curSupply < 3334) return _PRICE1;
        else if (curSupply < 6667) return _PRICE2;
        else return _PRICE3;
    }

    /**
     * @dev Send proceeds to creator address and incentives to rewarder contract.
     * @param newTokensSold Number of new sales
     */
    function _processWithdraw_ama(
        uint256 newTokensSold
    ) private returns (bool creatorPaid, bool rewarderPaid) {
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

// Quack! :)