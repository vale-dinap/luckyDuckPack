// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";

// TODO: replace ALL "REPLACE_ME" strings and double check all hardcoded values
// TODO: add commercial rights info

/**
 * @dev Lucky Duck Pack NFT contract
 *
 * The first NFT collection that pays sustainable, unstoppable, and 100%
 * smart-contract-powered lifetime yield to holders!
 *
 * By owning one or more tokens, holders receive a proportional share of
 * the creator fees from all trades; even if you never sell your own token,
 * you will still earn a lifetime yield from all the others being traded!
 *
 * All creator fee revenues are automatically sent to a "rewarder" contract,
 * which can be used by NFT holders to withdraw their share of dividends
 * at any time.
 *
 * Who's the best, a bunch of apes or a pack of ten thousand lucky ducks? ;)
 *
 *
 * About the code: the LDP smart-contracts have been written with the goal
 * of being not only as functional, optimized and secure as possible, but
 * also easily readable by anyone: even if you are not a programmer, why
 * don't you have a look at the code by yourself? Don't trust, verify!
 */
contract LuckyDuckPack is
    Ownable,                            // Admin role
    ERC721("Lucky Duck Pack", "LDP"),   // NFT token standard
    ERC2981,                            // Royalty info standard
    DefaultOperatorFilterer,            // Prevent trades on marketplaces not honoring creator fees
    VRFConsumerBase                     // Chainlink Random (for collection reveal)
{
    using Strings for uint256;

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
     * @notice What if either IPFS or Arweave goes down or becomes
     * corrupted/unreachable?
     * Very unlikely, of course... But really impossible?
     * I might as well be just a paranoid weirdo.
     * Yet, I stored the off-chain data of this NFT collection
     * on both, just in case.
     * When set to True, this variable causes the contract
     * to fetch off-chain data from Arweave instead of IPFS.
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

    // Chainlink VRF (Verifiable Random Function) - fair collection reveal
    address private constant VRFcoordinator = 0xf0d54349aDdcf704F77AE15b96510dEA15cb7952; // Contract
    uint256 private constant fee = 2 * 10**18; // 2 LINK fee on Ethereum Mainnet
    bytes32 private constant keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
    
    // Enumeration: Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    // Enumeration: Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    constructor()
        VRFConsumerBase(
            VRFcoordinator, // Chainlink VRF Coordinator
            0x514910771AF9Ca656af840dff83E8264EcF986CA // LINK Token
        )
    {}

    // EVENTS AND ERRORS //

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

    // FUNCTIONS //

    /**
     * @notice This is the only function restricted to admin, and admin keys
     * are burned by calling it. The function does the following:
     * store Minter contract address; set Rewarder contract address as
     * royalty receiver; set the Base URI; finally, burn the admin keys.
     * The data set by this function becomes immutable as amending it
     * would require admin permissions (keys burned with the first call).
     */
    function initialize(
        address minterAddress,
        address rewarderAddress,
        string calldata baseURI_IPFS,
        string calldata baseURI_AR
    ) external onlyOwner {
        require(minterAddress!=address(0), "Input Minter is zero address");
        require(rewarderAddress!=address(0), "Input Rewarder is zero address");
        require(bytes(baseURI_IPFS).length!=0, "Input IPFS base URI is empty");
        require(bytes(baseURI_AR).length!=0, "Input Arweave base URI is empty");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK token for reveal");
        minterContract = minterAddress;
        _baseURI_IPFS = baseURI_IPFS;
        _baseURI_AR = baseURI_AR;
        _setDefaultRoyalty(rewarderAddress, 800); // 800 basis points (8%)
        renounceOwnership();
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
     * @notice Mint function, callable only by the minter contract.
     * @param account Address to mint the token to.
     */
    function mint(address account) external {
        if(_msgSender() != minterContract) revert CallerIsNoMinter();
        require(totalSupply < MAX_SUPPLY, "No tokens left to be minted");
        uint256 nextId = totalSupply;
        totalSupply++;
        _safeMint(account, nextId);
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
     * @notice Token reveal (request randomness - Chainlink VRF).
     * This function can be called by anyone, but only after all tokens have been minted.
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
     * @notice Toggle off-chain data fetch location (IPFS / Arweave).
     * If both are reachable, calling this has basically no effect.
     * This function is unlikely to be useful, ever. But better safe than
     * sorry.
     */
    function toggleOffchainDataLocation() external {
        usingArweaveBackup ?
            usingArweaveBackup = false :
            usingArweaveBackup = true;
    }

    /**
     * @notice Callback function used by Chainlink VRF (collection reveal).
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        require(!_isRevealed(), "Already revealed"); // Ensure it's not called twice
        uint256 randomOffset = randomness % MAX_SUPPLY; // Compute the final value
        REVEAL_OFFSET = randomOffset == 0 ? 1 : randomOffset; // Offset cannot be zero
        emit RevealFulfilled(requestId, REVEAL_OFFSET);
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

    // CREATOR FEES INFO - ERC2981 //

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

    // CREATOR FEES ENFORCEMENT //
    // This section implements the Operator Filterer developed by Opensea (prevent
    // token sales on marketplaces that don't honor creator fees).
    
    /**
     * @dev Override to add {OperatorFilterer-onlyAllowedOperatorApproval} modifier.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev Override to add {OperatorFilterer-onlyAllowedOperatorApproval} modifier.
     */
    function approve(address operator, uint256 tokenId)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    /**
     * @dev Override to add {OperatorFilterer-onlyAllowedOperator} modifier.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Override to add {OperatorFilterer-onlyAllowedOperator} modifier.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev Override to add {OperatorFilterer-onlyAllowedOperator} modifier.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // OWNED TOKENS ENUMERATION //
    // This section contains functions that help retrieving all tokens owned by the
    // same address, used by the Rewarder contract to cash out all token revenues at once.

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
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
                _removeFromEnumeration(from, tokenId);
            }
            _addToEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Add a token to ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addToEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Remove a token from ownership-tracking data structures. Note that
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeFromEnumeration(address from, uint256 tokenId) private {
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
}
