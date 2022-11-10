// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import {DefaultOperatorFilterer} from "./lib/operator-filter-registry-main/src/DefaultOperatorFilterer.sol";

// TODO: test opensea code snippet
// TODO: test chainlinkVRF, consider replacing with V2
// TODO: update chainlinkVRF hardcoded variables (check values online)
// TODO: add ERC2981 fee data
// TODO: add contract intro comment
// TODO: replace contractURI with a pure function
// TODO: replace ALL "REPLACE_ME" strings

contract LuckyDucksPack is
    Ownable,
    ERC721("Lucky Ducks Pack", "LDP"),
    DefaultOperatorFilterer,
    VRFConsumerBase
    {
    using Strings for uint256;

    // Supply cap
    uint256 public constant MAX_SUPPLY = 10000;
    // Final provenance hash - hardcoded for transparency
    string public constant PROVENANCE = "REPLACE_ME";
    // URIs - hardcoded for efficiency and transparency
    string private constant baseURI = "REPLACE_ME"; // TODO: consider NOT hardcoding baseUri to avoid project to be cloned
    string private constant unrevealedURI = "REPLACE_ME";
    // Current total supply
    uint256 public totalSupply;
    // Minter contract address
    address public minterContract;
    /**
     * @notice When all tokens are minted, a random offset is generated via VRF;
     * [Revealed ID] = ([Token ID] + [Offset]) % [Max Supply].
     * As the offset is globally applied to all token IDs and generated
     * after all tokens have been minted, there is no way to snipe/cherrypick
     * tokens at minting time, therefore the distribution is truly hack-proof
     * as well as provably fair.
     */
    uint256 public REVEAL_OFFSET;
    address private constant VRFcoordinator =
        0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B;
    bool private _revealRequested;
    bytes32 private keyHash; // Required by VRF
    uint256 private fee; // Required by VRF

    constructor()
        VRFConsumerBase(
            VRFcoordinator, // VRF Coordinator
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709 // LINK Token
        )
    {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10**18; // 0.1 LINK (Varies by network)
    }

    // EVENTS //

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

    // FUNCTIONS //

    /**
     * @dev Set minter contract address. Immutable afterwards.
     */
    function setMinter(address newAddress) external onlyOwner {
        require(minterContract == address(0), "Already set");
        minterContract = newAddress;
    }

    /**
     * @notice Return the contract-level metadata URI.
     */
    function contractURI() public pure returns (string memory) {
        return "REPLACE_ME";
    }

    /**
     * @notice Return the token URI.
     * @param id Token ID.
     */
    function tokenURI(uint256 id) public view override returns (string memory) {
        require(_exists(id), "ERC721: URI query for nonexistent token"); // Ensure that the token exists.
        return
            _isRevealed() // If revealed,
                ? string(abi.encodePacked(baseURI, (revealedId(id)).toString())) // return baseURI + revealedId,
                : unrevealedURI; // otherwise return unrevealedURI.
    }
    
    /**
     * @dev Mint function callable only by minter contract.
     * @param account Address to mint the token to.
     */
    function mint(address account) external {
        require(
            _msgSender() == minterContract,
            "Caller is not the minter contract"
        );
        require(totalSupply < MAX_SUPPLY, "All minted");
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
     * @dev Callback function used by VRF Coordinator.
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        require(!_isRevealed(), "Already revealed"); // Cannot be called twice
        REVEAL_OFFSET = randomness % MAX_SUPPLY; // Compute the final value
        if (REVEAL_OFFSET == 0) REVEAL_OFFSET = 1; // Offset cannot be zero
        emit RevealFulfilled(requestId, REVEAL_OFFSET);
    }

    /**
     * @dev Return True if the collection is revealed.
     */
    function _isRevealed() private view returns (bool) {
        return REVEAL_OFFSET != 0;
    }

    // CREATOR FEES ENFORCEMENT //
    
    /**
     * @dev Override with {onlyAllowedOperator} modifier.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Override with {onlyAllowedOperator} modifier.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev Override with {onlyAllowedOperator} modifier.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
