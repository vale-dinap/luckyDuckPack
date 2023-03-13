// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";

// TODO: replace ALL "REPLACE_ME" strings and double check all hardcoded values

/**
 * @dev Lucky Duck Pack NFT contract
 *
 * The world's first NFT art collection that offers unstoppable, sustainable, 
 * and lifetime returns, all managed by smart-contracts!
 *
 * Simply owning one or more tokens grants holders a proportional share
 * of the creator fees from all trades. This means that even without
 * selling your own token, you can still receive lifetime earnings from
 * the trading of other tokens!
 *
 * The creator fee revenues are sent to a 'Rewarder' contract, which NFT
 * holders can access at any time to withdraw their share of earnings.
 * No staking, nor other actions, are required: own your token, claim
 * your earnings - it's THAT simple.
 *
 * Commercial rights: As long as you own a Lucky Duck Pack NFT, you are
 * granted an unlimited, worldwide, non-exclusive, royalty-free license to
 * use, reproduce, and display the underlying artwork for commercial purposes,
 * including creating and selling derivative work such as merchandise
 * featuring the artwork.
 *
 * About the code: the LDP smart-contracts have been designed with the aim
 * of being efficient, secure, transparent and accessible. Even if you
 * don't have a programming background, take a look at the code for yourself.
 * Don't trust, verify.
 */
contract LuckyDuckPack is
    Ownable,                            // Admin role
    ERC721("Lucky Duck Pack", "LDP"),   // NFT token standard
    ERC2981,                            // Royalty info standard
    DefaultOperatorFilterer,            // Prevent trades on marketplaces not honoring creator fees
    VRFConsumerBase                     // Chainlink Random (for collection reveal)
{
    using Strings for uint256;

    // =============================================================
    //                     CONTRACT VARIABLES
    // =============================================================

    // Supply cap
    uint256 public constant MAX_SUPPLY = 10000;
    // Final provenance hash - hardcoded for transparency
    string public constant PROVENANCE = "REPLACE_ME";
    // URIs - hardcoded for efficiency and transparency
    string private constant _unrevealedURI = "REPLACE_ME";
    string private constant _contractURI = "REPLACE_ME";
    // Base URI - to be set before minting (by calling {initialize})
    string private _baseURI_IPFS;
    string private _baseURI_AR;
    /**
     * @notice What if IPFS or Arweave experiences downtime or becomes
     * inaccessible? Although it's highly unlikely, one can never be too sure.
     * That's why I have stored the NFT collection's off-chain data on both
     * platforms as a precaution. The variable, when set to True, directs
     * the contract to retrieve the off-chain data from Arweave instead of IPFS.
     */
    bool public usingArweaveBackup;
    // Keeps track of the total supply
    uint256 public totalSupply;
    // Minter contract address
    address public minterContract;
    // Whether the reveal randomness has been requested to Chainlink
    bool private _revealRequested;
    /**
     * @notice After all tokens have been minted, a random offset number is
     * generated via VRF, so that:
     *
     * [Revealed ID] = ([Token ID] + [Offset]) % [Max Supply].
     *
     * As the random offset is applied to all token IDs and generated only after
     * all tokens have been already minted, there is no way to exploit the system
     * and snipe/cherrypick tokens with a higher rarity score; in other words, the
     * distribution is truly provably fair as well as hack-proof.
     */
    uint256 public REVEAL_OFFSET;
    /**
     * @notice Collection reveal timestamp.
     */
    uint256 public REVEAL_TIMESTAMP;

    // Chainlink VRF (Verifiable Random Function) - fair collection reveal
    address private constant VRFcoordinator = 0xf0d54349aDdcf704F77AE15b96510dEA15cb7952; // Contract
    uint256 private constant fee = 2 * 10**18; // 2 LINK fee on Ethereum Mainnet
    bytes32 private constant keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
    
    // Enumeration: Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    // Enumeration: Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor()
        VRFConsumerBase(
            VRFcoordinator, // Chainlink VRF Coordinator
            0x514910771AF9Ca656af840dff83E8264EcF986CA // LINK Token
        )
    {}

    // =============================================================
    //                      EVENTS AND ERRORS
    // =============================================================

    /**
     * @dev Emitted when the random reveal offset is requested to Chainlink VRF Coordinator.
     */
    event RevealRequested(bytes32 indexed requestId);

    /**
     * @dev Emitted when the reveal is fulfilled by Chainlink VRF Coordinator.
     */
    event RevealFulfilled(
        bytes32 indexed requestId,
        uint256 indexed randomNumber
    );

    /**
     * @dev Returned when a function reserved to the minter is called by a different address.
     */
    error CallerIsNoMinter();

    /**
     * @dev Returned when one or more of the initializer function parameters are empty/zero.
     */
    error EmptyInput(uint256 index);

    /**
     * @dev Returned when attempting to mint over the max supply.
     */
    error MaxSupplyExceeded();

    // =============================================================
    //                       MAIN FUNCTIONS
    // =============================================================

    /**
     * @notice Mint function, callable only by the minter contract.
     * @param account Address to mint the token to.
     * @param amount Amount of tokens to be minted.
     */
    function mint_Qgo(address account, uint256 amount) external {
        if(_msgSender() != minterContract) revert CallerIsNoMinter();
        uint256 supplyBefore = totalSupply;
        uint256 supplyAfter;
        unchecked{
            supplyAfter = supplyBefore + amount;
        }
        if(supplyAfter > MAX_SUPPLY) revert MaxSupplyExceeded();
        uint256 nextId = supplyBefore;
        for(nextId; nextId < supplyAfter;){
            _safeMint(account, nextId);
            unchecked{++nextId;}
        }
        totalSupply=supplyAfter;
    }

    /**
     * @notice This is the only function restricted to admin, and admin keys
     * are automatically burned when called. The function does the following:
     * store Minter contract address; set Rewarder contract address as
     * royalty receiver; set the Base URI; finally, burn the admin keys.
     * As admin keys are burnt, all the data set by this function becomes
     * effectively immutable.
     */
    function initialize(
        address minterAddress,
        address rewarderAddress,
        string calldata baseURI_IPFS,
        string calldata baseURI_AR
    ) external onlyOwner {
        // Input checks
        if(minterAddress==address(0)) revert EmptyInput(0);
        if(rewarderAddress==address(0)) revert EmptyInput(1);
        if(bytes(baseURI_IPFS).length==0) revert EmptyInput(2);
        if(bytes(baseURI_AR).length==0) revert EmptyInput(3);
        // Check if the contract has LINK tokens (required for collection reveal)
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK token for reveal");
        // Store data
        minterContract = minterAddress;
        _baseURI_IPFS = baseURI_IPFS;
        _baseURI_AR = baseURI_AR;
        _setDefaultRoyalty(rewarderAddress, 800); // 800 basis points (8%)
        // Burn admin keys
        renounceOwnership();
    }

    /**
     * @notice Collection reveal (request randomness - Chainlink VRF).
     * This function can be called only once and by anyone, but only after
     * all tokens have been minted.
     */
    function reveal() external returns (bytes32 requestId) {
        require(MAX_SUPPLY == totalSupply, "Called before minting completed");
        require(!_revealRequested, "Reveal already requested");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        _revealRequested = true;
        requestId = requestRandomness(keyHash, fee);
        emit RevealRequested(requestId);
    }

    /**
     * @notice Callback function used by Chainlink VRF (for collection reveal).
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        require(!_isRevealed(), "Already revealed"); // Ensure it's not called twice
        uint256 randomOffset = randomness % MAX_SUPPLY; // Compute the final value
        REVEAL_OFFSET = randomOffset == 0 ? 1 : randomOffset; // Offset cannot be zero
        REVEAL_TIMESTAMP = block.timestamp;
        emit RevealFulfilled(requestId, REVEAL_OFFSET);
    }

    /**
     * @notice Change the location from which the offchain data is fetched
     * (IPFS / Arweave). If both locations are reachable, calling this has
     * basically no effect. This function is unlikely to be useful, ever.
     * But, better safe than sorry.
     */
    function toggleOffchainDataLocation() external {
        usingArweaveBackup ?
            usingArweaveBackup = false :
            usingArweaveBackup = true;
    }

    /**
     * @notice Get the revealed ID.
     * @param id Token ID.
     */
    function revealedId(uint256 id) public view virtual returns (uint256) {
        require(_isRevealed(), "Collection not revealed");
        return (id + REVEAL_OFFSET) % MAX_SUPPLY;
    }

    /**
     * @notice Return the contract metadata URI.
     */
    function contractURI() public pure returns (string memory) {
        return _contractURI;
    }

    /**
     * @notice Return the token URI.
     * @param id Token ID.
     */
    function tokenURI(uint256 id) public view override returns (string memory) {
        require(_exists(id), "URI query for nonexistent token"); // Ensure that the token exists.
        return
            _isRevealed() // If revealed,
                ? string(abi.encodePacked(_actualBaseURI(), revealedId(id).toString())) // return baseURI+revealedId,
                : _unrevealedURI; // otherwise return the unrevealedURI.
    }

    /**
     * @dev Return True if the collection is revealed.
     */
    function _isRevealed() private view returns (bool) {
        return REVEAL_OFFSET != 0;
    }

    /**
     * @dev Return either Arweave or IPFS baseURI depending on the
     * value of "usingArweaveBackup".
     */
    function _actualBaseURI() private view returns (string memory) {
        return usingArweaveBackup ? _baseURI_AR : _baseURI_IPFS;
    }

    // =============================================================
    //                 TOKEN OWNERSHIP ENUMERATION
    // =============================================================

    // This section contains functions that help retrieving all tokens owned by the
    // same address, used by the Rewarder contract to cash out all token revenues at once.

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256)
    {
        require(index < ERC721.balanceOf(owner), "Index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev Adds owner enumeration to token transfers.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        if (from != to) {
            if (from != address(0)) {
                _removeFromEnumeration_bIF(from, tokenId);
            }
            _addToEnumeration_j9B(to, tokenId);
        }
    }

    /**
     * @dev Add a token to ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addToEnumeration_j9B(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Remove a token from ownership-tracking data structures. Note that
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeFromEnumeration_bIF(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];
            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    // =============================================================
    //                   CREATOR FEES ENFORCEMENT
    // =============================================================

    // This section implements the Operator Filterer developed by Opensea (prevent
    // token sales on marketplaces that don't honor creator fees).
    
    /**
     * @dev Adds {OperatorFilterer-onlyAllowedOperatorApproval} modifier.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev Adds {OperatorFilterer-onlyAllowedOperatorApproval} modifier.
     */
    function approve(address operator, uint256 tokenId)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    /**
     * @dev Adds {OperatorFilterer-onlyAllowedOperator} modifier.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Adds {OperatorFilterer-onlyAllowedOperator} modifier.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev Adds {OperatorFilterer-onlyAllowedOperator} modifier.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // =============================================================
    //                  ERC2981 (CREATOR FEES INFO)
    // =============================================================

    /**
     * @dev Override required for ERC2981 support
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC2981)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

}

// :)