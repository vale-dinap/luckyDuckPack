// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @dev Interface to interact with the {LuckyDucksPack} contract.
 */
interface ILDP{
    /**
     * @dev Mints a new token.
     * @param account Destination address.
     */
    function mint(address account) external;
    /**
     * @dev Returns the current total supply.
     */
    function totalSupply() view external returns(uint256);
    /**
     * @dev Returns the supply cap.
     */
    function MAX_SUPPLY() view external returns(uint256);
    /**
     * @dev Returns the token balance of `owner`.
     */
    function balanceOf(address owner) view external returns(uint256);
    /**
     * @dev Returns the address owner of `tokenId`.
     */
    function ownerOf(uint256 tokenId) view external returns(address);
    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) view external returns (uint256);
}