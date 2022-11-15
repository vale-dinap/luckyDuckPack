// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/interfaces/ILDP.sol";
import "./lib/interfaces/ILDPMinterPayee.sol";

/**
 * @dev Lucky Ducks Pack minter contract.
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
    // Instance of the minting payee contract
    ILDPMinterPayee public payee;

    /**
     * @notice Link the token contract instance to the nft contract address.
     * Can be set only once, then it becomes immutable.
     */
    function setNftAddress(address nftAddr) external onlyOwner{
        require(address(nft)==address(0), "Overriding denied");
        nft = ILDP(nftAddr);
    }
    
    /**
     * @notice Link the payee contract instance to the payee contract address.
     */
    function setPayeeAddress(address payeeAddr) external onlyOwner{
        require(payeeAddr!=address(0));
        payee = ILDPMinterPayee(payeeAddr);
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
            require(startTime>block.timestamp, "Input startTime is in the past");
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
        if(amount>10) revert("Attempted to mint more than 10");
        // Revert if underpaying
        require(msg.value>=_currentPrice()*amount, "Price paid incorrect");
        // Forward payment to payee address
        payee.processPayment{value: msg.value}(amount);
        // Finally, mint tokens
        _mintBatch(amount);
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
}