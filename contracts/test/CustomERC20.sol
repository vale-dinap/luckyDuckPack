// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract CustomERC20A is ERC20PresetFixedSupply {
    constructor(
        address tokenHolder
    )
        ERC20PresetFixedSupply(
            "CustomERC20A",
            "TOKENA",
            100 * 10 ** 18,
            tokenHolder
        )
    {}
}

contract CustomERC20B is ERC20PresetFixedSupply {
    constructor(
        address tokenHolder
    )
        ERC20PresetFixedSupply(
            "CustomERC20B",
            "TOKENB",
            100 * 10 ** 18,
            tokenHolder
        )
    {}
}