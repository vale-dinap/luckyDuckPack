// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

contract LinkToken is ERC20PresetFixedSupply, LinkTokenInterface {
    constructor(
        address tokenHolder
    ) ERC20PresetFixedSupply(
        "Link",
        "LINK",
        1000 * 10 ** 18,
        tokenHolder
        )
    {}

    /**
  * @dev transfer token to a specified address with additional data if the recipient is a contract.
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  * @param _data The extra data to be passed to the receiving contract.
  */
  function transferAndCall(address _to, uint _value, bytes memory _data)
    public
    validRecipient(_to)
    returns (bool success)
  {
    super.transfer(_to, _value);
    //emit Transfer(msg.sender, _to, _value, _data);
    if (isContract(_to)) {
      contractFallback(_to, _value, _data);
    }
    return true;
  }

  /**
  * @dev transfer token to a specified address.
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint _value)
    public
    override(ERC20, LinkTokenInterface)
    validRecipient(_to)
    returns (bool success)
  {
    return super.transfer(_to, _value);
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value)
    public
    override(ERC20, LinkTokenInterface)
    validRecipient(_spender)
    returns (bool)
  {
    return super.approve(_spender,  _value);
  }

  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value)
    public
    override(ERC20, LinkTokenInterface)
    validRecipient(_to)
    returns (bool)
  {
    return super.transferFrom(_from, _to, _value);
  }

  function contractFallback(address _to, uint _value, bytes memory _data)
    private
  {
    ERC677Receiver receiver = ERC677Receiver(_to);
    receiver.onTokenTransfer(msg.sender, _value, _data);
  }

  function isContract(address _addr)
    private
    returns (bool hasCode)
  {
    uint length;
    assembly { length := extcodesize(_addr) }
    return length > 0;
  }

  function decreaseApproval (address _spender, uint _subtractedValue) external returns(bool success){
    //Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function increaseApproval (address _spender, uint _subtractedValue) external {
    //Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return;
  }

  function totalSupply() view public override(ERC20, LinkTokenInterface) returns(uint256){
    return ERC20.totalSupply();
  }

  function symbol() view public override(ERC20, LinkTokenInterface) returns(string memory){
    return ERC20.symbol();
  }

  function name() view public override(ERC20, LinkTokenInterface) returns(string memory){
    return ERC20.name();
  }

  function decimals() view public override(ERC20, LinkTokenInterface) returns(uint8){
    return ERC20.decimals();
  }

  function balanceOf(address account) view public override(ERC20, LinkTokenInterface) returns(uint256){
    return ERC20.balanceOf(account);
  }

  function allowance(address owner, address spender) view public override(ERC20, LinkTokenInterface) returns(uint256){

    return ERC20.allowance(owner, spender);
  }

  // MODIFIERS

  modifier validRecipient(address _recipient) {
    require(_recipient != address(0) && _recipient != address(this));
    _;
  }

}

abstract contract ERC677Receiver {
  function onTokenTransfer(address _sender, uint _value, bytes memory _data) public virtual;
}