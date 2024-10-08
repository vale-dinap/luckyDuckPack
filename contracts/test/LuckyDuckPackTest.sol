// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

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
contract LuckyDuckPackTest is
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
    uint256 public immutable MAX_SUPPLY;
    // Keeps track of the total supply
    uint256 public totalSupply;
    // Final provenance hash - hardcoded for transparency
    string public constant PROVENANCE = "a10f0c8e99734955d7ff53ac815a1d95aa1daa413e1d6106cb450d584c632b0b";
    // When the provenance record was stored in the smart-contract
    uint256 public immutable PROVENANCE_TIMESTAMP;
    // Location where the collection information is stored
    string private _contract_URI;
    // Where the unrevealed token data is stored
    string private _unrevealed_URI;
    // Location prefix for token metadata (and images)
    string private _baseURI_IPFS; // IPFS
    string private _baseURI_AR; // Arweave
    /**
     * @notice What if the data stored on IPFS or Arweave or becomes
     * inaccessible? Although it's unlikely, one can never be too sure.
     * That's why we have stored the NFT collection's off-chain data on both
     * networks as a precaution. This variable, when set to True, directs
     * the contract to retrieve the off-chain data from Arweave instead of IPFS.
     */
    bool public useArweaveUri;
    // Deployer address
    address public immutable DEPLOYER;
    // Minter contract address
    address public minterContract;
    // Whether the reveal randomness has been already requested to Chainlink
    bool private _revealRequested;
    /**
     * @notice Once all tokens have been minted, a random offset number is
     * generated using VRF (Verifiable Random Function). This offset is then added
     * to the Token ID, and the resulting value is taken modulo of the maximum
     * supply of tokens to obtain the Revealed ID:
     *
     * [Revealed ID] = ([Token ID] + [Offset]) % [Max Supply]
     *
     * As the random offset is applied uniformly to all token IDs only after the
     * minting process is completed, the system cannot be exploited to cherry-pick
     * tokens with a higher rarity score. In other words, the distribution is
     * guaranteed to be fair and resistant to any potential hacks.
     */
    uint256 public revealOffset;
    /**
     * @notice Collection reveal timestamp.
     */
    uint256 public revealTimestamp;

    // Chainlink VRF (Verifiable Random Function) - fair collection reveal
    address private immutable VRFcoordinator; // Contract
    uint256 private constant fee = 2 * 10**18; // 2 LINK fee on Ethereum Mainnet
    bytes32 private constant keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
    
    // Enumeration: Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    // Enumeration: Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor(address _VRFcoordinator, address _linkToken, uint256 maxSupply)
        VRFConsumerBase(
            _VRFcoordinator, // Chainlink VRF Coordinator
            _linkToken // LINK Token
        )
    {
        VRFcoordinator = _VRFcoordinator;
        PROVENANCE_TIMESTAMP = block.timestamp;
        DEPLOYER = msg.sender;
        MAX_SUPPLY = maxSupply;
    }

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
     * @dev Error returned when the mint function is called by a different address than the minter contract.
     */
    error CallerIsNoMinter();

    /**
     * @dev Error returned when one or more function parameters are empty/zero.
     */
    error EmptyInput(uint256 index);

    /**
     * @dev Error returned when attempting to mint over the max supply.
     */
    error MaxSupplyExceeded(uint256 excess);

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
        unchecked{ // Can be unchecked because the minter contract restricts amount to be <= 10
            supplyAfter = supplyBefore + amount;
        }
        if(supplyAfter > MAX_SUPPLY) revert MaxSupplyExceeded(supplyAfter - MAX_SUPPLY);
        totalSupply=supplyAfter;
        for(uint256 nextId = supplyBefore; nextId < supplyAfter;){
            _mint(account, nextId);
            unchecked{++nextId;}
        }
    }

    /**
     * @notice This is the only function restricted to admin, and admin keys
     * are automatically burned when called. The function does the following:
     * store Minter contract address; set Rewarder contract address as royalty
     * receiver; set the Base URI and Contract URI; finally, burn the admin keys.
     * As admin keys are burnt, all the data set by this function becomes
     * effectively immutable.
     */
    function initialize(
        address minterAddress,
        address rewarderAddress,
        string calldata contract_URI,
        string calldata unrevealed_URI,
        string calldata baseURI_IPFS,
        string calldata baseURI_AR
    ) external onlyOwner {
        // Validate input
        if(minterAddress==address(0)) revert EmptyInput(0);
        if(rewarderAddress==address(0)) revert EmptyInput(1);
        if(bytes(contract_URI).length==0) revert EmptyInput(2);
        if(bytes(unrevealed_URI).length==0) revert EmptyInput(3);
        if(bytes(baseURI_IPFS).length==0) revert EmptyInput(4);
        if(bytes(baseURI_AR).length==0) revert EmptyInput(5);
        /// Ensure the contract has enough LINK tokens for the collection reveal
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK for reveal");
        // Store the provided data
        minterContract = minterAddress;
        _contract_URI = contract_URI;
        _unrevealed_URI = unrevealed_URI;
        _baseURI_IPFS = baseURI_IPFS;
        _baseURI_AR = baseURI_AR;
        // Set the default royalty for the rewarder address
        _setDefaultRoyalty(rewarderAddress, 800); // 800 basis points (8%)
        // Burn admin keys to make the data effectively immutable
        renounceOwnership();
    }

    /**
     * @notice Change the location from which the offchain data is fetched
     * (IPFS / Arweave). If both locations are reachable, calling this has
     * basically no effect. This function is only useful if case the data
     * becomes unavailable/unreachable on one of the two networks.
     * For security reasons, only the contract deployer is allowed to use
     * this toggle.
     * Better safe than sorry.
     */
    function toggleArweaveUri() external {
        require(msg.sender == DEPLOYER, "Permission denied.");
        useArweaveUri = !useArweaveUri;
    }

    /**
     * @notice Collection reveal (request randomness - Chainlink VRF).
     * This function can be called only once and by anyone, but only after
     * all tokens have been minted.
     */
    function reveal() external returns (bytes32 requestId) {
        require(totalSupply == MAX_SUPPLY, "Minting still in progress");
        require(!_revealRequested, "Reveal already requested");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        _revealRequested = true;
        requestId = requestRandomness(keyHash, fee);
        emit RevealRequested(requestId);
    }

    /**
     * @notice Callback function used by Chainlink VRF (for collection reveal).
     * Only Chainlink has permissions to call it.
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        require(!_isRevealed(), "Already revealed"); // Ensure it's not called twice
        uint256 randomOffset = randomness % MAX_SUPPLY; // Compute the final value
        revealOffset = randomOffset == 0 ? 1 : randomOffset; // Offset cannot be zero
        revealTimestamp = block.timestamp;
        emit RevealFulfilled(requestId, revealOffset);
    }

    /**
     * @notice Get the revealed ID.
     * @param id Token ID.
     */
    function revealedId(uint256 id) public view virtual returns (uint256) {
        require(_isRevealed(), "Collection not revealed");
        return (id + revealOffset) % MAX_SUPPLY;
    }

    /**
     * @notice Return the contract metadata URI.
     */
    function contractURI() public view returns (string memory) {
        return _contract_URI;
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
                : _unrevealed_URI; // otherwise return the unrevealedURI.
    }

    /**
     * @dev Return True if the collection is revealed.
     */
    function _isRevealed() private view returns (bool) {
        return revealOffset != 0;
    }

    /**
     * @dev Return either Arweave or IPFS baseURI depending on the
     * value of "useArweaveUri".
     */
    function _actualBaseURI() private view returns (string memory) {
        return useArweaveUri ? _baseURI_AR : _baseURI_IPFS;
    }

    // =============================================================
    //                 TOKEN OWNERSHIP ENUMERATION
    // =============================================================

    // This section contains functions that help retrieving all tokens owned by the
    // same address, used by the Rewarder contract to cash out the revenues from all
    // the owned tokens at once.

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

// Quack! :)