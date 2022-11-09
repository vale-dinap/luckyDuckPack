// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract LuckyDucksPack is Ownable, ERC721 {
    using Strings for uint256;

    // Supply cap
    uint256 public constant MAX_SUPPLY = 10000;
    // Final provenance hash - hardcoded for transparency
    string public constant PROVENANCE = "REPLACE_ME";
    // URIs - hardcoded for efficiency and transparency
    string constant baseURI = "REPLACE_ME";
    string constant unrevealedURI = "REPLACE_ME";
    string public constant contractURI = "REPLACE_ME";
    // Total supply
    uint256 public totalSupply;
    // Minter contract address
    address public minterContract;
    /**
     * @notice When all tokens are minted, a random offset is generated;
     * [Revealed ID] = ([Token ID] + [Offset]) % [Max Supply].
     * As the offset is globally applied to all token IDs and generated
     * after all tokens have been minted, there is no way to snipe/cherrypick
     * tokens at minting time, therefore the minting is provably fair.
     */
    uint256 public REVEAL_OFFSET;

    constructor() ERC721("Lucky Ducks Pack", "LDP") {}

    /**
     * @dev Set minter contract address. Immutable afterwards.
     */
    function setMinter(address newAddress) external onlyOwner {
        require(minterContract == address(0), "Already set");
        minterContract = newAddress;
    }

    /**
     * @notice Return the token URI.
     * @param id Token ID.
     */
    function tokenURI(uint256 id) public view override returns (string memory) {
        require(_exists(id), "ERC721: URI query for nonexistent token"); // Ensure that the token exists.
        return
            _isRevealed() ? // If revealed,
                string(abi.encodePacked(baseURI, (revealedId(id)).toString())) // return revealed URI (baseURI + id),
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
        _safeMint(account, totalSupply);
        totalSupply++;
    }

    /**
    * @notice Get the revealed ID.
    * @param id Token ID.
    */
    function revealedId(uint256 id) view public virtual returns(uint256){
        require(_isRevealed(), "Collection not revealed");
        return (id + REVEAL_OFFSET) % MAX_SUPPLY;
    }
    
    /**
     * @dev Return True if the collection is revealed.
     */
    function _isRevealed() view private returns(bool){
        return REVEAL_OFFSET != 0;
    }

    /**
    * @dev Token reveal.
    */
    function _reveal() private {
        require(MAX_SUPPLY == totalSupply, "Called before minting completed");
        require(!_isRevealed(), "Already revealed");
        while (REVEAL_OFFSET == 0){
            //REVEAL_OFFSET = MAX_SUPPLY.randMax();
            //TODO: Implement VRF
        }
    }
}
