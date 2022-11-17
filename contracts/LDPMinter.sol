// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/interfaces/ILDP.sol";

/**
 * @dev Lucky Ducks Pack Minter contract.
 */
contract LDPMinter is Ownable, ReentrancyGuard{

    // Pricing
    uint256 private constant _price1 = 1.3 ether; // From 1 to 3333
    uint256 private constant _price2 = 1.8 ether; // From 3334 to 6666
    uint256 private constant _price3 = 2.3 ether; // From 6667 to 10000
    // Minting start time (Unix timestamp)
    uint256 public mintingStartTime;
    // Instance of the token contract
    ILDP public nft;
    // Creator
    address private creator;
    // LDP Rewarder contract address
    address public rewarder;

    error MaxMintsPerCallExceeded(uint256 requested, uint256 max);
    error PaymentError();

    /**
     * @notice Link the token contract instance to the nft contract address.
     * Can be set only once, then it becomes immutable.
     */
    function setNftAddress(address nftAddr) external onlyOwner{
        require(address(nft)==address(0), "Overriding denied");
        nft = ILDP(nftAddr);
    }
    
    /**
     * @notice Set the payee address.
     */
    function setCreatorAddress(address creatorAddr) external onlyOwner{
        require(creatorAddr!=address(0), "Input is zero address");
        creator = creatorAddr;
    }

    /**
     * @notice Set the LDP Rewarder contract address. Locked after minting starts.
     */
    function setRewarderAddress(address rewarderAddr) external onlyOwner{
        require(block.timestamp<mintingStartTime, "Access denied: minting started");
        require(rewarderAddr!=address(0), "Input is zero address");
        rewarder = rewarderAddr;
    }

    /**
     * @notice Set minting start time and reserve 10 tokens to admin's address.
     * @dev This function cannot be called more than once, so admin won't be able to
     * grab more than 10 free tokens (0.1% of the supply).
     * @param startTime Minting start time (Unix timestamp)
     */
    function initializeMinting(uint256 startTime) external onlyOwner {
        if(mintingStartTime>0) revert("Already initialized");
        else{
            require(startTime>block.timestamp, "Requested time is in the past");
            mintingStartTime = startTime;
            _mintBatch(10);
        }
    }

    /**
     * @notice Mint (buy) tokens to the caller address.
     * @param amount Number of tokens to be minted, max 10 per transaction.
     */
    function mint(uint256 amount) external payable nonReentrant {
        // Revert if minting hasn't started
        require(block.timestamp>mintingStartTime, "Minting not started");
        // Revert if attempting to mint more than 10 tokens at once
        if(amount>10) revert MaxMintsPerCallExceeded({requested: amount, max:10});
        // Revert if underpaying
        require(msg.value>=_currentPrice()*amount, "Price paid incorrect");
        // Finally, mint tokens
        _mintBatch(amount);
        // Send payment to creator and LDP Rewarder contract
        _processPayment(msg.value, amount);
    }

    /**
     * @notice Shows how many tokens are left to be minted.
     */
    function mintableSupply() view external returns(uint256){
        return nft.MAX_SUPPLY()-nft.totalSupply();
    }

    /**
     * @notice Shows the current price.
     */
    function currentPrice() view external returns(uint256){
        return _currentPrice();
    }

    /**
     * @dev Returns the current price (depends on the minted supply).
     */
    function _currentPrice() view private returns(uint256){
        uint256 curSupply = nft.totalSupply();
        if(curSupply<3334) return _price1;
        else if (curSupply<6667) return _price2;
        else return _price3;
    }

    /**
     * @dev Mint multiple tokens.
     */
    function _mintBatch(uint256 amount) private{
        for(uint256 i=0; i<amount; ++i){
            nft.mint(msg.sender);
        }
    }

    /**
     * @dev Send payment to creator address and incentives to rewarder contract.
     * @param payAmount Total amount of ether being paid
     * @param purchaseAmount Amount of NFTs being purchased
     */
    function _processPayment(uint256 payAmount, uint256 purchaseAmount) private{
        uint256 creatorEarnings = payAmount - (0.3 ether * purchaseAmount);
        (bool creatorPaid, ) = creator.call{value: creatorEarnings}("");
        (bool rewarderPaid, ) = rewarder.call{value: 0.3 ether}("");
        if(!(creatorPaid && rewarderPaid)) revert PaymentError();
    }
}