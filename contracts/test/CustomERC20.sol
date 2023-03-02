// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract CustomERC20A is ERC20PresetMinterPauser("CustomERC20A", "TOKENA"){}

contract CustomERC20B is ERC20PresetMinterPauser("CustomERC20B", "TOKENB"){}