// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/interfaces/ILDP.sol";
import "./lib/tools/WethUnwrapper.sol";

// TODO: double-check erc20 mechanics (and look for optimizations)
// TODO: event when revenues are received?

/**
 * @dev Lucky Duck Pack Rewarder
 *
 * This contract receives 100% of the creator fees from LDP trades.
 * Whenever funds are received, a portion of it is set aside for each LDP token;
 * token owners can claim their earnings at any moment by calling {cashout}.
 *
 * The contract reserves 6.25% of the earnings for the collection creator, with
 * the remaining 93.75% going to token holders proportionally to the number of
 * tokens they own.
 *
 * The earnings are tied to the tokens, not to the holder addresses, meaning that
 * if an NFT is sold or transferred without claiming its earnings first, the new
 * owner will have the right to do so.
 *
 * Supported currencies are ETH and WETH by default. In the event that creator fees
 * are received in other currencies, a separate set of functions to manually
 * process/cashout any ERC20 token -callable by anyone- is provided.
 *
 * This contract is fair, unstoppable, unpausable, immutable: the admin only has
 * the authority to change the creator cashout address, but has no access to the
 * contract's liquidity or funds earned by NFT holders.
 */
contract LDPRewarder is Ownable, ReentrancyGuard {
    /**
     * @dev Type defining revenues info.
     * Keeps track of lifetime earnings and lifetime cashout of each NFT, so that:
     * [newEarnings] = [lifetimeEarned] - [lifetimeCollected]
     */
    struct Revenues {
        uint256 lifetimeEarnings; // Lifetime earnings of each NFT
        uint256 creatorLifetimeEarnings; // Lifetime earnings of the creator
        uint256 creatorLifetimeCollected; // Lifetime earnings collected by creator
        mapping(uint256 => uint256) lifetimeCollected; // NFT ID => amount
    }

    // ETH revenues data
    Revenues private _revenues;
    // ERC20 tokens revenues data
    mapping(address => Revenues) private _erc20Revenues; // Token address => Revenues
    // Track the processed ERC20 revenues to identify funds received since last records update
    mapping(address => uint256) private _processedErc20Revenues; // Token address => balance

    // Creator address - only for cashout: creator has no special permissions
    address private _creator;
    // Lucky Duck Pack NFT contract
    ILDP public nft;
    // WETH token address and WETH Unwrapper contract
    address private constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    WethUnwrapper private immutable wethUnwrapper;

    /**
     * @dev Failsafe: set admin address as default beneficiary of
     * creator earnings. Can amend it afterwards.
     * Initialize the WETH unwrapper contract.
     */
    constructor() {
        _creator = msg.sender;
        wethUnwrapper = new WethUnwrapper(weth);
    }

    // EVENTS AND ERRORS //

    /**
     * @dev Emitted when ETH is withdrawn.
     */
    event Cashout(address indexed account, uint256 indexed amount);
    /**
     * @dev Emitted when an ERC20-token is withdrawn.
     */
    event CashoutErc20(
        address indexed account,
        uint256 indexed amount,
        address indexed token
    );
    /**
     * @dev Raised on payout errors.
     */
    error CashoutError();
    /**
     * @dev Emitted by {noWeth} modifier when ERC20-reserved operations are
     * attempted on WETH; check {noWeth} documentation for more info.
     */
    error NotAllowedOnWETH();

    /**
     * @dev Earnings in Wrapped Ether (WETH) are automatically converted to ETH
     * by the contract, so they don't have to be claimed separately; this modifier
     * prevents ERC20 functions from operating with WETH (as doing so might cause
     * unwanted behaviours).
     */
    modifier noWeth(address tokenContract) {
        if(tokenContract == weth) revert NotAllowedOnWETH();
        _;
    }

    // ADMIN FUNCTIONS //

    /**
     * @notice Link the token contract instance to the nft contract address.
     * Can be set only once and becomes immutable afterwards.
     */
    function setNftAddress(address nftAddr) external onlyOwner {
        require(address(nft) == address(0), "Overriding denied");
        nft = ILDP(nftAddr);
    }

    /**
     * @notice Admin function to amend the creator address.
     */
    function setCreatorAddress(address newAddress) external onlyOwner {
        require(newAddress != address(0));
        _creator = newAddress;
    }

    // RECEIVE FUNCTION //

    /**
     * @dev When eth funds are received, this function:
     * -updates the ETH revenue records;
     * -unwraps any previously received WETH and adds
     *  these unwrapped funds to the ETH revenue records.
     */
    receive() external payable {
        _updateRevenueRecords_tku(msg.value);
        _unwrapWethIfAny__um();
    }

    // USER FUNCTIONS //

    /**
     * @notice Cashout the revenues accrued by all owned NFTs.
     */
    function cashout() external nonReentrant {
        _accountCashout_dHm(msg.sender);
    }

    /**
     * @notice Cashout revenues accrued by the specified NFT.
     */
    function nftCashout(uint256 tokenId) external nonReentrant {
        _nftCashout_M29(tokenId);
    }

    /**
     * @notice Similar to {cashout} but works with any ERC20 token.
     * @param tokenAddress Address of the ERC20 token contract
     */
    function cashoutErc20(address tokenAddress) external noWeth(tokenAddress) {
        _updateErc20Revenues_a8w(tokenAddress);
        _accountCashout_h8W(msg.sender, tokenAddress);
    }

    /**
     * @notice Same as {nftCashout}, but working with any ERC20 token.
     * @param tokenAddress Address of the ERC20 token contract
     */
    function nftCashoutErc20(uint256 tokenId, address tokenAddress) external {
        _nftCashout_0G0(tokenId, tokenAddress);
    }

    /**
     * @notice Cashout the creator revenues.
     */
    function creatorCashout() external nonReentrant {
        _creatorCashout_89e();
    }

    /**
     * @notice Similar to {creatorCashout} but works with any ERC20 token.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function creatorCashoutErc20(address tokenAddress)
        external
        noWeth(tokenAddress)
    {
        _creatorCashout_gl3(tokenAddress);
    }

    /**
     * @notice Returns the sum of all revenues accrued by the tokens owned by
     * the given account; the function {isErc20RevenueRecordsUpToDate} can be
     * used to check if these records are already up to date; if not, records
     * can be updated by calling {forceUpdateTokenRevenueRecords}.
     */
    function accountRevenues(address account)
        external
        view
        returns (uint256 accruedRevenues)
    {
        uint256 numOwned = nft.balanceOf(account);
        for (uint256 i; i < numOwned;) {
            unchecked {
                accruedRevenues += _getNftRevenues_idw(
                    _revenues,
                    nft.tokenOfOwnerByIndex(account, i)
                );
                ++i;
            }
        }
    }

    /**
     * @notice ERC20-token version of {accountRevenues(address)}.
     * @param account Holder's address.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function accountRevenuesErc20(address account, address tokenAddress)
        external
        view
        returns (uint256 accruedRevenues)
    {
        if (tokenAddress == weth) return 0;
        else {
            uint256 numOwned = nft.balanceOf(account);
            for (uint256 i; i < numOwned;) {
                unchecked {
                    accruedRevenues += _getNftRevenues_idw(
                        _erc20Revenues[tokenAddress],
                        nft.tokenOfOwnerByIndex(account, i)
                    );
                    ++i;
                }
            }
        }
    }

    /**
     * @notice Returns the revenues accrued by the token `tokenId`.
     */
    function nftRevenues(uint256 tokenId) external view returns (uint256) {
        return _getNftRevenues_idw(_revenues, tokenId);
    }

    /**
     * @notice ERC20-token version of {nftRevenues(uint256)}.
     * @param tokenId Id of the LDP nft.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function nftRevenuesErc20(uint256 tokenId, address tokenAddress)
        external
        view
        returns (uint256)
    {
        if (tokenAddress == weth) return 0;
        else return _getNftRevenues_idw(_erc20Revenues[tokenAddress], tokenId);
    }

    /**
     * @notice Returns true if the revenue records of the provided ERC20 token
     * are up to date.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function isErc20RevenueRecordsUpToDate(address tokenAddress)
        external
        view
        returns (bool)
    {
        if (tokenAddress == weth) return true;
        else
            return
                IERC20(tokenAddress).balanceOf(address(this)) ==
                _processedErc20Revenues[tokenAddress];
    }

    /**
     * @notice Force updating the revenue records of the provided ERC20 token:
     * while ETH and WETH are automatically updated by {receive}, this is not
     * possible with ERC20 tokens, so a manual update might be required.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function forceUpdateErc20RevenueRecords(address tokenAddress)
        external
        noWeth(tokenAddress)
    {
        _updateErc20Revenues_a8w(tokenAddress);
    }

    // INTERNAL LOGICS

    /**
     * @dev If this smart-contract holds any WETH, unwrap it.
     * By doing so, the receive function is also called which causes
     * the unwrapped ETH to be added to the revenue records. This is
     * a workaround as normally the automatic revenues distribution
     * could not occur if the creator fees are received in WETH.
     */
    function _unwrapWethIfAny__um() private {
        uint256 bal = IWETH(weth).balanceOf(address(this));
        if (bal != 0) {
            IWETH(weth).transfer(address(wethUnwrapper), bal);
            wethUnwrapper.unwrap_aof(bal);
            wethUnwrapper.withdraw_wdp();
        }
    }

    /**
     * @dev Send to `account` all ETH revenues accrued by its tokens.
     * @param account Account address
     */
    function _accountCashout_dHm(address account) private {
        uint256 amount;
        uint256 numOwned = nft.balanceOf(account);
        for (uint256 i; i < numOwned;) {
            unchecked {
                amount += _processWithdrawData_Il8(
                    _revenues,
                    nft.tokenOfOwnerByIndex(account, i)
                );
                ++i;
            }
        }
        _cashout_qLL({recipient: account, amount: amount});
    }

    /**
     * @dev ERC20-token version of {_accountCashout_dHm}.
     * @param account Account address
     * @param tokenAddress Address of the ERC20 token contract
     */
    function _accountCashout_h8W(address account, address tokenAddress) private {
        uint256 amount;
        uint256 numOwned = nft.balanceOf(account);
        for (uint256 i; i < numOwned;) {
            unchecked {
                amount += _processWithdrawData_Il8(
                    _erc20Revenues[tokenAddress],
                    nft.tokenOfOwnerByIndex(account, i)
                );
                ++i;
            }
        }
        _cashout_KTv({token: tokenAddress, recipient: account, amount: amount});
    }

    /**
     * @dev Send all ETH revenues accrued by the token `tokenId` to its
     * current owner.
     */
    function _nftCashout_M29(uint256 tokenId) private {
        address account = nft.ownerOf(tokenId);
        uint256 amount = _processWithdrawData_Il8(_revenues, tokenId);
        _cashout_qLL({recipient: account, amount: amount});
    }

    /**
     * @dev ERC20-token version of {_nftCashout_M29}.
     * @param tokenId Id of the token to be used for cashout
     * @param tokenAddress Address of the ERC20 token contract
     */
    function _nftCashout_0G0(uint256 tokenId, address tokenAddress) private {
        address account = nft.ownerOf(tokenId);
        uint256 amount = _processWithdrawData_Il8(
            _erc20Revenues[tokenAddress],
            tokenId
        );
        _cashout_KTv({token: tokenAddress, recipient: account, amount: amount});
    }

    /**
     * @dev Send creator revenues to their address.
     */
    function _creatorCashout_89e() private {
        uint256 earnings = _processWithdrawDataCreator_sFU(_revenues);
        _cashout_qLL({recipient: _creator, amount: earnings});
    }

    /**
     * @dev ERC20-token version of {_creatorCashout_89e}.
     * @param tokenAddress Address of the ERC20 token contract.
     */
    function _creatorCashout_gl3(address tokenAddress) private {
        uint256 earnings = _processWithdrawDataCreator_sFU(
            _erc20Revenues[tokenAddress]
        );
        _cashout_KTv({token: tokenAddress, recipient: _creator, amount: earnings});
    }

    /**
     * @dev Updates ETH revenue records. This function is embedded in
     * the receive() fallback, therefore automatically called whenever
     * new ETH is received.
     * @param newRevenues Amount of ETH to be added to the revenue records.
     */
    function _updateRevenueRecords_tku(uint256 newRevenues) private {
        uint256 creatorsCut;
        uint256 holdersCut;
        (creatorsCut, holdersCut) = _calculateCuts_42r(newRevenues);
        unchecked {
            _revenues.lifetimeEarnings += (holdersCut / 10000);
            _revenues.creatorLifetimeEarnings += creatorsCut;
        }
    }

    /**
     * @dev Same logics of {_updateRevenueRecords_tku} with any ERC20 token.
     * @param newRevenues Amount to be added to revenues
     * @param tokenAddress Address of the ERC20 token contract
     * @param tokenBalance Up-to-date token balance of this contract
     */
    function _updateRevenueRecords_e20(
        uint256 newRevenues,
        address tokenAddress,
        uint256 tokenBalance
    ) private {
        uint256 creatorsCut;
        uint256 holdersCut;
        (creatorsCut, holdersCut) = _calculateCuts_42r(newRevenues);
        unchecked {
            _erc20Revenues[tokenAddress].lifetimeEarnings += (holdersCut /
                10000);
            _erc20Revenues[tokenAddress].creatorLifetimeEarnings += creatorsCut;
        }
        _processedErc20Revenues[tokenAddress] = tokenBalance;
    }

    /**
     * @dev Calls {_updateRevenueRecords_e20} to update the token revenue
     * records, but only if the records of the specified ERC20 token are
     * not up to date.
     * Note: this cannot be called automatically when receiving ERC20 token
     * transfers. As a workaround, it is called by {cashoutErc20} before
     * performing the actual withdraw.
     * @param tokenAddress Address of the ERC20 token contract
     */
    function _updateErc20Revenues_a8w(address tokenAddress) private {
        uint256 curBalance = IERC20(tokenAddress).balanceOf(address(this));
        uint256 processedRevenues = _processedErc20Revenues[tokenAddress];
        if (curBalance != processedRevenues) {
            unchecked {
                _updateRevenueRecords_e20(
                    curBalance - processedRevenues,
                    tokenAddress,
                    curBalance
                );
            }
        }
    }

    /**
     * @dev Called when revenues are claimed: returns the amount of revenues
     * claimable by the specified token ID and records that these revenues
     * have now been collected.
     * @param tokenId Id of the LDP token
     */
    function _processWithdrawData_Il8(
        Revenues storage revenueRecords,
        uint256 tokenId
    ) private returns (uint256 accruedRevenues) {
        uint256 lifetimeEarnings = revenueRecords.lifetimeEarnings;
        unchecked {
            accruedRevenues =
                lifetimeEarnings -
                revenueRecords.lifetimeCollected[tokenId];
        }
        revenueRecords.lifetimeCollected[tokenId] = lifetimeEarnings;
    }

    /**
     * @dev Same as {_processWithdrawData_Il8} but working on creator revenues:
     * returns the amount of revenues claimable by the collection creator
     * and records that these revenues have now been collected.
     */
    function _processWithdrawDataCreator_sFU(Revenues storage revenueRecords)
        private
        returns (uint256 accruedRevenues)
    {
        uint256 lifetimeEarnings = revenueRecords.creatorLifetimeEarnings;
        unchecked {
            accruedRevenues =
                lifetimeEarnings -
                revenueRecords.creatorLifetimeCollected;
        }
        revenueRecords.creatorLifetimeCollected = lifetimeEarnings;
    }

    /**
     * @dev Returns the unclaimed revenues accrued by the given tokenId.
     */
    function _getNftRevenues_idw(Revenues storage revenueRecords, uint256 tokenId)
        private
        view
        returns (uint256)
    {
        unchecked {
            return
                revenueRecords.lifetimeEarnings -
                revenueRecords.lifetimeCollected[tokenId];
        }
    }

    /**
     * @dev Calculate holders and creator revenues from the given amount.
     */
    function _calculateCuts_42r(uint256 amount)
        private
        pure
        returns (uint256 creatorsCut, uint256 holdersCut)
    {
        unchecked {
            creatorsCut = amount / 16; // 6.25% to creator
            holdersCut = amount - creatorsCut; // 93.75% to holders
        }
    }

    /**
     * @dev Private function used by cashout functions to transfer funds.
     * @param recipient Destination to send funds to
     * @param amount Amount to be sent
     */
    function _cashout_qLL(address recipient, uint256 amount) private {
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert CashoutError();
        emit Cashout(recipient, amount);
    }

    /**
     * @dev ERC20-token version of {_cashout_qLL}.
     * @param token ERC20 token address
     * @param recipient Destination to send funds to
     * @param amount Amount to be sent
     */
    function _cashout_KTv(
        address token,
        address recipient,
        uint256 amount
    ) private {
        bool success = IERC20(token).transfer(recipient, amount);
        if (!success) revert CashoutError();
        unchecked{_processedErc20Revenues[token] -= amount;}
        emit CashoutErc20(recipient, amount, token);
    }
}